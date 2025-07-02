// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:http/http.dart' as http;

import '../models/message_model.dart';
import '../models/order_model.dart';
import '../services/message_service.dart';
import '../constants/app_colors.dart';

/*
🐛 GUIDE DE DÉBUGGAAGE POUR LES ERREURS DE CHAT :

1. ❌ "Erreur lors de l'envoi du message" même quand ça marche :
   - Vérifiez les logs dans la console : cherchez "✅ [MESSAGE] Message envoyé avec succès"
   - Si vous voyez le succès dans les logs mais l'erreur à l'écran = problème de validation de réponse
   - Vérifiez que votre MessageService retourne bien un objet avec .data valide

2. 📸 Images qui ne partent pas :
   - Vérifiez les logs "🌐 [DOWNLOAD] Status Code: 200"
   - Si Status Code != 200 = problème d'URL d'image
   - Modifiez la baseUrl dans _buildFullImageUrl() selon votre serveur

3. 🌐 Problèmes de connectivité :
   - Regardez les logs "🌐 [TEST] Test connectivité serveur"
   - Modifiez l'IP dans _testServerConnectivity() pour correspondre à votre serveur

4. 🔍 Debug avancé :
   - Cherchez "🔴 [ERROR_CHECK] Vraie erreur" vs "🟡 [ERROR_CHECK] Possible fausse erreur"
   - Les fausses erreurs sont ignorées et ne s'affichent pas à l'utilisateur

🎨 NOUVELLES FONCTIONNALITÉS UX :
   
✅ Messages de succès VERTS (plus de rouge pour les succès)
🎯 Animations plus douces pour l'apparition des messages  
⏱️ Délais plus longs entre les envois pour une meilleure perception
📱 Messages de progression pour l'envoi des images de commande
🔄 Vérification automatique si un message est passé malgré une erreur apparente
*/

class ChatScreen extends StatefulWidget {
  final String partnerName;
  final String? partnerPhoto;
  final bool isOnline;
  final int partnerId;
  
  // 🆕 NOUVEAUX PARAMÈTRES POUR LES COMMANDES
  final String? prefilledMessage;
  final Order? orderContext;
  final bool isFromOrder;

  const ChatScreen({
    Key? key,
    required this.partnerName,
    this.partnerPhoto,
    this.isOnline = false,
    required this.partnerId,
    this.prefilledMessage,
    this.orderContext,
    this.isFromOrder = false,
  }) : super(key: key);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  final MessageService _messageService = MessageService();
  final ImagePicker _picker = ImagePicker();
  
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentRecordingPath;
  Timer? _recordingTimer;
  
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _isRecording = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSendingOrderImages = false;
  bool _recordingFinished = false;
  Duration _recordingDuration = Duration.zero;
  
  late AnimationController _recordingAnimationController;
  late Animation<double> _recordingAnimation;

  List<Message> _messages = [];
  Partner? _partner;
  int? _currentUserId;

  static const Color primaryColor = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _recordingAnimationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _recordingAnimation = Tween<double>(
      begin: 0.8,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _recordingAnimationController,
      curve: Curves.easeInOut,
    ));
    
    _messageController.addListener(_onTextChanged);
    
    // 🆕 REMPLIR LE MESSAGE SI FOURNI
    if (widget.prefilledMessage != null && widget.prefilledMessage!.isNotEmpty) {
      _messageController.text = widget.prefilledMessage!;
      setState(() {
        _isTyping = true;
      });
    }
    
    _initializeChat();
    
    // 🆕 SI C'EST DEPUIS UNE COMMANDE, ENVOYER AUTOMATIQUEMENT
    if (widget.isFromOrder && widget.orderContext != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _sendOrderWithImages();
      });
    }
  }

  Future<void> _initializeChat() async {
    await _getCurrentUserId();
    await _loadMessages();
  }

  Future<void> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getInt('current_user_id');
      
      if (_currentUserId == null) {
        _currentUserId = 13;
        await prefs.setInt('current_user_id', _currentUserId!);
      }
    } catch (e) {
      _currentUserId = 13;
    }
  }

  Future<void> _loadMessages() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await _messageService.getMessages(widget.partnerId);
      
      if (mounted) {
        setState(() {
          _messages = response.messages;
          _partner = response.partner;
          _isLoading = false;
        });
        
        _scrollToBottom();
        _markAllAsRead();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        _showError('Erreur lors du chargement des messages');
      }
    }
  }

  Future<void> _markAllAsRead() async {
    try {
      await _messageService.markAllAsRead(widget.partnerId);
    } catch (e) {
      // Ignore silently
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    _recordingAnimationController.dispose();
    _recordingTimer?.cancel();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _isTyping) {
      setState(() {
        _isTyping = hasText;
      });
    }
  }

  // 🕰️ MÉTHODE POUR VÉRIFIER L'ÂGE DU MESSAGE (30 MINUTES)
  bool _canDeleteForEveryone(Message message) {
    final now = DateTime.now();
    final messageAge = now.difference(message.createdAt);
    const thirtyMinutes = Duration(minutes: 30);
    
    return messageAge <= thirtyMinutes;
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty || _isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      print('📤 [MESSAGE] Début envoi: ${text.substring(0, text.length > 50 ? 50 : text.length)}...');
      
      final response = await _messageService.sendMessage(
        widget.partnerId,
        text,
      );
      
      // ✅ VÉRIFICATION AMÉLIORÉE DE LA RÉPONSE
      bool isSuccess = false;
      
      if (response != null && response.data != null) {
        print('✅ [MESSAGE] Réponse valide reçue - ID: ${response.data.id}');
        isSuccess = true;
      } else {
        print('⚠️ [MESSAGE] Réponse nulle, vérification...');
        // Attendre un peu puis vérifier si le message est apparu
        await Future.delayed(const Duration(milliseconds: 1500));
        final oldCount = _messages.length;
        await _loadMessages();
        isSuccess = _messages.length > oldCount;
        print(isSuccess ? '✅ [MESSAGE] Message détecté après rechargement' : '❌ [MESSAGE] Message non détecté');
      }
      
      if (isSuccess && mounted) {
        setState(() {
          _messageController.clear();
          _isSending = false;
        });
        
        // 🎯 AJOUTER LE MESSAGE AVEC ANIMATION DOUCE
        if (response?.data != null) {
          _addMessageWithAnimation(response!.data);
        }
        
        // 🎯 MESSAGE DE SUCCÈS VERT DISCRET
        _showSuccessMessage('Message envoyé', duration: 1);
        
      } else if (mounted) {
        setState(() {
          _isSending = false;
        });
        _showError('Le message n\'a pas pu être envoyé');
      }
      
    } catch (e) {
      print('❌ [MESSAGE] Exception capturée: $e');
      
      // 🔍 ANALYSE INTELLIGENTE DES ERREURS
      final errorString = e.toString().toLowerCase();
      bool isNetworkError = errorString.contains('socket') || 
                           errorString.contains('network') || 
                           errorString.contains('connection');
      
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        
        if (isNetworkError) {
          _showError('Problème de connexion réseau');
        } else {
          // Pour toute autre erreur, vérifier si le message est quand même passé
          print('🔍 [MESSAGE] Vérification post-erreur...');
          await Future.delayed(const Duration(milliseconds: 1000));
          
          final oldCount = _messages.length;
          await _loadMessages();
          
          if (_messages.length > oldCount) {
            print('✅ [MESSAGE] Message envoyé malgré l\'exception');
            setState(() {
              _messageController.clear();
            });
            _showSuccessMessage('Message envoyé', duration: 1);
          } else {
            _showError('Erreur lors de l\'envoi du message');
          }
        }
      }
    }
  }

  // 🆕 MÉTHODE POUR ENVOYER COMMANDE + IMAGES
  /// 🆕 MÉTHODE UTILITAIRE : Envoyer un message texte simple
Future<void> _sendTextMessage(String content) async {
  try {
    print('📝 [TEXT_UTIL] Envoi: ${content.substring(0, content.length > 50 ? 50 : content.length)}...');
    
    final response = await _messageService.sendMessage(
      widget.partnerId,
      content,
    );
    
    if (response?.data != null) {
      print('✅ [TEXT_UTIL] Message envoyé avec succès');
      
      if (mounted) {
        // 🎯 UTILISER LA NOUVELLE MÉTHODE D'ANIMATION
        _addMessageWithAnimation(response!.data);
      }
    } else {
      print('⚠️ [TEXT_UTIL] Réponse vide mais pas d\'exception');
      // Recharger les messages au cas où
      await _loadMessages();
    }
  } catch (e) {
    print('❌ [TEXT_UTIL] Erreur envoi texte: $e');
    // Ne pas afficher d'erreur à l'utilisateur pour les messages utilitaires
    // car c'est souvent utilisé en arrière-plan
  }
}
// 🔧 REMPLACER dans votre chat_screen.dart

/// 🛒 Envoyer commande + images SEULEMENT du marchand concerné - VERSION AMÉLIORÉE
Future<void> _sendOrderWithImages() async {
  if (widget.orderContext == null || _isSendingOrderImages) return;
  
  setState(() {
    _isSendingOrderImages = true;
  });
  
  try {
    final order = widget.orderContext!;
    
    // 1. ENVOYER D'ABORD LE MESSAGE TEXTE
    if (_messageController.text.isNotEmpty) {
      await _sendMessage();
      await Future.delayed(const Duration(milliseconds: 1500)); // Plus de temps
    }
    
    // 🎯 2. FILTRER LES PRODUITS AVEC IMAGES POUR CE MARCHAND SEULEMENT
    final productsWithImages = order.orderItems
        .where((item) => item.product.firstImageUrl.isNotEmpty)
        .toList();
    
    if (productsWithImages.isNotEmpty) {
      // 🌐 3. TESTER LA CONNECTIVITÉ AVANT D'ENVOYER LES IMAGES
      print('🌐 [ORDER] Test de connectivité au serveur...');
      final serverAccessible = await _testServerConnectivity();
      
      if (!serverAccessible) {
        _showSnackBar('⚠️ Serveur non accessible. Envoi des descriptions uniquement.', duration: 4);
        
        // Envoyer seulement les descriptions sans images
        for (final item in productsWithImages) {
          final description = '''📦 ${item.product.name} (x${item.quantity})
💰 ${item.formattedTotalPrice}
🖼️ Image: ${item.product.firstImageUrl}''';
          
          try {
            final response = await _messageService.sendMessage(widget.partnerId, description);
            if (response?.data != null && mounted) {
              _addMessageWithAnimation(response!.data);
            }
            await Future.delayed(const Duration(milliseconds: 1000)); // Plus de temps entre messages
          } catch (e) {
            print('❌ [DESCRIPTION] Erreur: $e');
          }
        }
        return;
      }
      
      // 🎯 MESSAGE DE DÉBUT AVEC STYLE
      _showSnackBar('📸 Préparation de ${productsWithImages.length} image(s)...', duration: 3);
      
      int successCount = 0;
      int errorCount = 0;
      
      // 4. ENVOYER LES IMAGES UNE PAR UNE AVEC PLUS DE DÉLAIS
      for (int i = 0; i < productsWithImages.length; i++) {
        final item = productsWithImages[i];
        
        // 🎯 AFFICHAGE DU PROGRÈS
        if (productsWithImages.length > 1) {
          _showSnackBar('📤 Envoi ${i + 1}/${productsWithImages.length}: ${item.product.name}', duration: 2);
        }
        
        try {
          print('🔄 [ORDER_SEND] Envoi ${i + 1}/${productsWithImages.length}: ${item.product.name}');
          await _sendProductImageAsMedia(item, i + 1, productsWithImages.length);
          successCount++;
          
          // 🎯 PAUSE PLUS LONGUE ENTRE CHAQUE PRODUIT
          if (i < productsWithImages.length - 1) {
            await Future.delayed(const Duration(milliseconds: 2000)); // Plus lent
          }
        } catch (e) {
          errorCount++;
          print('❌ [ORDER_IMAGE] Erreur pour ${item.product.name}: $e');
          // Continue avec les autres images même en cas d'erreur
        }
      }
      
      // 5. AFFICHER LE RÉSULTAT FINAL AVEC COULEURS APPROPRIÉES
      if (successCount > 0 && errorCount == 0) {
        _showSuccessMessage('✨ ${successCount} image(s) envoyée(s) avec succès !', duration: 3);
      } else if (successCount > 0 && errorCount > 0) {
        _showSnackBar('⚡ ${successCount} succès, ${errorCount} échec(s)', duration: 3);
      } else {
        _showError('❌ Aucune image n\'a pu être envoyée');
      }
    } else {
      _showSnackBar('ℹ️ Aucune image de produit à envoyer');
    }
    
  } catch (e) {
    print('❌ [ORDER_IMAGES] Erreur générale: $e');
    _showError('⚠️ Erreur lors de l\'envoi des images');
  } finally {
    if (mounted) {
      setState(() {
        _isSendingOrderImages = false;
      });
    }
  }
}

/// 🆕 NOUVELLE MÉTHODE : Envoyer l'image d'un produit comme VRAIE image média - VERSION AMÉLIORÉE
Future<void> _sendProductImageAsMedia(OrderItem item, int currentIndex, int totalImages) async {
  try {
    print('📸 [PRODUCT_IMAGE] [$currentIndex/$totalImages] Début envoi: ${item.product.name}');
    print('📸 [PRODUCT_IMAGE] URL: ${item.product.firstImageUrl}');
    
    // 🔧 ÉTAPE 1 : Envoyer le titre/description en texte
    final productDescription = '''📦 **${item.product.name}**
💰 ${item.product.formattedPrice} × ${item.quantity} = ${item.formattedTotalPrice}''';
    
    try {
      print('📝 [TEXT] Envoi description produit...');
      final textResponse = await _messageService.sendMessage(
        widget.partnerId,
        productDescription,
      );
      
      if (textResponse?.data != null && mounted) {
        // 🎯 AJOUTER AVEC ANIMATION DOUCE
        _addMessageWithAnimation(textResponse!.data);
        print('✅ [TEXT] Description envoyée avec succès');
      }
    } catch (e) {
      print('❌ [TEXT] Erreur envoi description: $e');
      throw Exception('Échec envoi description: $e');
    }
    
    // 🎯 PAUSE PLUS LONGUE ENTRE TEXTE ET IMAGE POUR UNE MEILLEURE UX
    await Future.delayed(const Duration(milliseconds: 1200));
    
    // 🔧 ÉTAPE 2 : Télécharger et envoyer l'image
    print('📸 [IMAGE] Téléchargement image...');
    final imageFile = await _downloadImageFromUrl(item.product.firstImageUrl);
    
    if (imageFile != null) {
      try {
        print('📸 [IMAGE] Envoi du fichier image...');
        final imageResponse = await _messageService.sendMessage(
          widget.partnerId,
          '🖼️ Image produit', // Message descriptif pour l'image
          mediaFile: imageFile,
        );
        
        if (imageResponse?.data != null && mounted) {
          // 🎯 AJOUTER AVEC ANIMATION DOUCE
          _addMessageWithAnimation(imageResponse!.data);
          print('✅ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Image envoyée avec succès: ${item.product.name}');
        }
      } catch (e) {
        print('❌ [IMAGE] Erreur envoi image: $e');
        throw Exception('Échec envoi image: $e');
      } finally {
        // 🔧 NETTOYER le fichier temporaire
        try {
          if (await imageFile.exists()) {
            await imageFile.delete();
            print('🗑️ [CLEANUP] Fichier temporaire supprimé');
          }
        } catch (e) {
          print('⚠️ [CLEANUP] Erreur suppression fichier: $e');
        }
      }
    } else {
      print('❌ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Échec téléchargement: ${item.product.name}');
      
      // 🔧 FALLBACK : Envoyer au moins le texte avec l'URL
      final fallbackMessage = '''📦 ${item.product.name} (x${item.quantity})
💰 ${item.formattedTotalPrice}
🖼️ Image : ${item.product.firstImageUrl}''';
      
      try {
        final fallbackResponse = await _messageService.sendMessage(
          widget.partnerId,
          fallbackMessage,
        );
        
        if (fallbackResponse?.data != null && mounted) {
          _addMessageWithAnimation(fallbackResponse!.data);
          print('✅ [FALLBACK] Message de fallback envoyé');
        }
      } catch (e) {
        print('❌ [FALLBACK] Erreur envoi fallback: $e');
        throw Exception('Échec complet envoi produit: $e');
      }
    }
  } catch (e) {
    print('❌ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Exception générale ${item.product.name}: $e');
    
    // 🔧 DERNIER FALLBACK EN CAS D'ERREUR TOTALE
    try {
      final errorMessage = '''⚠️ Erreur envoi produit
📦 ${item.product.name} (x${item.quantity})
💰 ${item.formattedTotalPrice}''';
      
      final errorResponse = await _messageService.sendMessage(
        widget.partnerId,
        errorMessage,
      );
      
      if (errorResponse?.data != null && mounted) {
        _addMessageWithAnimation(errorResponse!.data);
        print('✅ [ERROR_FALLBACK] Message d\'erreur envoyé');
      }
    } catch (finalError) {
      print('❌ [ERROR_FALLBACK] Échec final: $finalError');
    }
    
    // Re-lancer l'exception pour que l'appelant sache qu'il y a eu une erreur
    rethrow;
  }
}
  Future<void> _sendProductImage(OrderItem item, int currentIndex, int totalImages) async {
    try {
      print('📸 [PRODUCT_IMAGE] [$currentIndex/$totalImages] Envoi: ${item.product.name}');
      print('📸 [PRODUCT_IMAGE] URL: ${item.product.firstImageUrl}');
      
      // Télécharger l'image depuis l'URL
      final imageFile = await _downloadImageFromUrl(item.product.firstImageUrl);
      
      if (imageFile != null) {
        // Créer un message descriptif pour l'image
        final imageMessage = '📦 ${item.product.name} (x${item.quantity})';
        
        // Envoyer l'image comme message média
        final response = await _messageService.sendMessage(
          widget.partnerId,
          imageMessage,
          mediaFile: imageFile,
        );
        
        if (mounted) {
          setState(() {
            _messages.add(response.data);
          });
          
          _scrollToBottom();
          print('✅ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Envoyé: ${item.product.name}');
        }
        
        // Supprimer le fichier temporaire
        if (await imageFile.exists()) {
          await imageFile.delete();
        }
      } else {
        print('❌ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Échec téléchargement: ${item.product.name}');
        throw Exception('Impossible de télécharger l\'image de ${item.product.name}');
      }
    } catch (e) {
      print('❌ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Exception ${item.product.name}: $e');
      rethrow;
    }
  }

  // 🆕 MÉTHODE POUR TÉLÉCHARGER UNE IMAGE DEPUIS UNE URL
  Future<File?> _downloadImageFromUrl(String imageUrl) async {
    try {
      // 🔧 CONSTRUIRE L'URL COMPLÈTE SI NÉCESSAIRE
      String fullImageUrl = _buildFullImageUrl(imageUrl);
      print('⬇️ [DOWNLOAD] URL originale: $imageUrl');
      print('⬇️ [DOWNLOAD] URL complète: $fullImageUrl');
      
      final response = await http.get(Uri.parse(fullImageUrl)).timeout(
        const Duration(seconds: 15),
      );
      
      print('🌐 [DOWNLOAD] Status Code: ${response.statusCode}');
      print('📄 [DOWNLOAD] Content Length: ${response.contentLength}');
      
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Créer un fichier temporaire
        final tempDir = await getTemporaryDirectory();
        final fileName = 'product_${DateTime.now().millisecondsSinceEpoch}_${_generateRandomString(6)}.jpg';
        final file = File('${tempDir.path}/$fileName');
        
        // Écrire les données de l'image
        await file.writeAsBytes(response.bodyBytes);
        
        // Vérifier que le fichier existe et n'est pas vide
        if (await file.exists() && await file.length() > 0) {
          print('✅ [DOWNLOAD] Téléchargé: ${file.path} (${await file.length()} bytes)');
          return file;
        } else {
          print('❌ [DOWNLOAD] Fichier vide ou inexistant');
          return null;
        }
      } else {
        print('❌ [DOWNLOAD] Erreur HTTP ${response.statusCode} ou body vide');
        return null;
      }
    } catch (e) {
      print('❌ [DOWNLOAD] Exception: $e');
      return null;
    }
  }

  // 🆕 CONSTRUIRE L'URL COMPLÈTE DE L'IMAGE - VERSION AMÉLIORÉE
  String _buildFullImageUrl(String imageUrl) {
    // Si l'URL est déjà complète (contient http), la retourner telle quelle
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      print('🌐 [URL] URL déjà complète: $imageUrl');
      return imageUrl;
    }
    
    // 🔧 PLUSIEURS OPTIONS D'URL DE BASE À TESTER
    const List<String> possibleBaseUrls = [
      'http://192.168.1.100:3000',  // IP locale
      'http://localhost:3000',      // Localhost
      'http://10.0.2.2:3000',      // Émulateur Android
      'https://your-domain.com',    // Domaine production
    ];
    
    // Utiliser la première URL de base (modifiez selon votre configuration)
    const String baseUrl = 'http://192.168.1.100:3000'; // 📝 MODIFIEZ CETTE LIGNE !
    
    // Supprimer le slash initial si présent pour éviter les doubles slashes
    String cleanPath = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    
    // Construire l'URL complète
    String fullUrl = '$baseUrl/$cleanPath';
    
    print('🌐 [URL] URL construite: $fullUrl');
    return fullUrl;
  }

  // 🆕 GÉNÉRER UNE CHAÎNE ALÉATOIRE POUR LES NOMS DE FICHIERS
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecond % chars.length]).join();
  }

  // 🆕 MÉTHODE POUR TESTER LA CONNECTIVITÉ AU SERVEUR
  Future<bool> _testServerConnectivity() async {
    try {
      const String testUrl = 'http://192.168.1.100:3000'; // 📝 MODIFIEZ SELON VOTRE SERVEUR
      print('🌐 [TEST] Test connectivité serveur: $testUrl');
      
      final response = await http.get(Uri.parse(testUrl)).timeout(
        const Duration(seconds: 5),
      );
      
      print('🌐 [TEST] Réponse serveur: ${response.statusCode}');
      return response.statusCode < 500; // Accepter tout sauf erreurs serveur
    } catch (e) {
      print('❌ [TEST] Serveur non accessible: $e');
      return false;
    }
  }

  // 🆕 MÉTHODE POUR VALIDER LA RÉPONSE DU SERVICE DE MESSAGE
  bool _isValidMessageResponse(dynamic response) {
    if (response == null) {
      print('⚠️ [VALIDATION] Réponse null');
      return false;
    }
    
    if (response.data == null) {
      print('⚠️ [VALIDATION] response.data est null');
      return false;
    }
    
    print('✅ [VALIDATION] Réponse valide - ID: ${response.data.id}');
    return true;
  }

  // 🆕 MÉTHODE POUR DISTINGUER LES VRAIES ERREURS DES FAUSSES
  bool _isRealError(dynamic error) {
    String errorString = error.toString().toLowerCase();
    
    // Les vraies erreurs que nous voulons signaler
    List<String> realErrors = [
      'socketexception',
      'timeout',
      'connection refused',
      'network is unreachable',
      'no internet connection',
      'formatexception',
      'unauthorized',
      'forbidden',
    ];
    
    for (String realError in realErrors) {
      if (errorString.contains(realError)) {
        print('🔴 [ERROR_CHECK] Vraie erreur détectée: $realError');
        return true;
      }
    }
    
    print('🟡 [ERROR_CHECK] Possible fausse erreur: $error');
    return false;
  }

  // 🆕 MÉTHODE DE DEBUG - AFFICHE LES INFORMATIONS TECHNIQUES (optionnel)
  void _showDebugInfo() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🔍 Informations de débogage'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('👤 Partner ID: ${widget.partnerId}'),
              Text('💬 Messages count: ${_messages.length}'),
              Text('🔄 Is sending: $_isSending'),
              Text('📤 Is sending order images: $_isSendingOrderImages'),
              const SizedBox(height: 16),
              const Text('🌐 URLs de test:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('- Server: http://192.168.1.100:3000'),
              const Text('- Test connectivity avant envoi images'),
              const SizedBox(height: 16),
              const Text('📝 Logs importants à surveiller:', style: TextStyle(fontWeight: FontWeight.bold)),
              const Text('✅ [MESSAGE] Message envoyé avec succès'),
              const Text('❌ [MESSAGE] Exception capturée'),
              const Text('🔴 [ERROR_CHECK] Vraie erreur'),
              const Text('🟡 [ERROR_CHECK] Possible fausse erreur'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              // Test de connectivité
              final isConnected = await _testServerConnectivity();
              _showSnackBar(
                isConnected ? '✅ Serveur accessible' : '❌ Serveur non accessible',
                duration: 3,
              );
            },
            child: const Text('Tester serveur'),
          ),
        ],
      ),
    );
  }

  Future<void> _editMessage(Message message) async {
    final TextEditingController editController = TextEditingController(text: message.content);
    
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le message'),
        content: TextField(
          controller: editController,
          decoration: const InputDecoration(
            hintText: 'Nouveau contenu...',
            border: OutlineInputBorder(),
          ),
          maxLines: 3,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              final newText = editController.text.trim();
              if (newText.isNotEmpty && newText != message.content) {
                Navigator.pop(context, newText);
              } else {
                Navigator.pop(context);
              }
            },
            child: const Text('Modifier', style: TextStyle(color: primaryColor)),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty && result != message.content) {
      try {
        _showSnackBar('⏳ Modification en cours...');
        
        final response = await _messageService.updateMessage(message.id, result);
        
        if (mounted) {
          setState(() {
            final index = _messages.indexWhere((m) => m.id == message.id);
            if (index != -1) {
              if (response != null && response.data != null) {
                _messages[index] = response.data;
              } else {
                _messages[index] = _messages[index].copyWith(content: result);
              }
            }
          });
          
          _showSnackBar('✅ Message modifié avec succès');
        }
      } catch (e) {
        if (mounted) {
          String errorMessage = 'Erreur lors de la modification';
          if (e.toString().contains('404')) {
            errorMessage = 'Message non trouvé';
          } else if (e.toString().contains('403')) {
            errorMessage = 'Vous ne pouvez pas modifier ce message';
          }
          
          _showSnackBar('❌ $errorMessage');
        }
      }
    }
  }

  bool _shouldShowMessage(Message message) {
    if (_currentUserId == null) return true;
    
    if (message.senderId == _currentUserId && message.deletedForSender) {
      return false;
    }
    
    if (message.receiverId == _currentUserId && message.deletedForReceiver) {
      return false;
    }
    
    return true;
  }

  List<Message> get _visibleMessages {
    return _messages.where(_shouldShowMessage).toList();
  }

  Future<void> _deleteMessageForMe(Message message) async {
    if (_currentUserId == null) {
      _showSnackBar('❌ Vous devez être connecté', duration: 2);
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Supprimer pour moi'),
        content: Text(
          'Ce message sera supprimé uniquement pour vous.\n\n'
          'Message: "${message.content.length > 50 ? message.content.substring(0, 50) + "..." : message.content}"'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      _showSnackBar('⏳ Suppression en cours...', duration: 1);
      
      await _messageService.deleteMessage(message.id, forEveryone: false);
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            if (message.senderId == _currentUserId) {
              _messages[index] = _messages[index].copyWith(deletedForSender: true);
            } else {
              _messages[index] = _messages[index].copyWith(deletedForReceiver: true);
            }
          }
        });
        
        _showSnackBar('✅ Message supprimé pour vous', duration: 2);
      }
      
      await _reloadMessages();
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erreur lors de la suppression';
        
        if (e.toString().contains('403')) {
          errorMessage = 'Non autorisé à supprimer ce message';
        } else if (e.toString().contains('404')) {
          errorMessage = 'Message non trouvé';
        }
        
        _showSnackBar('❌ $errorMessage', duration: 3);
      }
    }
  }

  Future<void> _deleteMessageForEveryone(Message message) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Supprimer pour tout le monde'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('⚠️ Ce message sera supprimé définitivement pour tous les participants.'),
            const SizedBox(height: 8),
            const Text('Cette action est irréversible.'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Text(
                'Message: "${message.content.length > 50 ? message.content.substring(0, 50) + "..." : message.content}"',
                style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Supprimer définitivement'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      _showSnackBar('⏳ Suppression en cours...');
      
      await _messageService.deleteMessage(message.id, forEveryone: true);
      
      if (mounted) {
        setState(() {
          final index = _messages.indexWhere((m) => m.id == message.id);
          if (index != -1) {
            _messages[index] = _messages[index].copyWith(
              deletedForEveryone: true,
              content: 'Ce message a été supprimé',
              mediaUrl: null,
              mediaType: MediaType.text,
            );
          }
        });
        
        _showSnackBar('✅ Message supprimé pour tout le monde');
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Erreur lors de la suppression';
        if (e.toString().contains('404')) {
          errorMessage = 'Message non trouvé';
        } else if (e.toString().contains('403')) {
          errorMessage = 'Vous ne pouvez pas supprimer ce message';
        }
        
        _showSnackBar('❌ $errorMessage');
      }
    }
  }

  Future<void> _reloadMessages() async {
    try {
      final messagesResponse = await _messageService.getMessages(widget.partnerId);
      
      if (mounted) {
        setState(() {
          _messages = messagesResponse.messages;
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnackBar('⚠️ Erreur lors de la synchronisation', duration: 2);
      }
    }
  }

  Future<void> _takePicture() async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      
      if (image != null) {
        final file = File(image.path);
        await _sendRealMediaMessage('📸 Photo', file);
      }
    } catch (e) {
      _showSnackBar('❌ Erreur lors de la prise de photo');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final result = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (context) => Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Que voulez-vous sélectionner ?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _GalleryOption(
                    icon: Icons.photo,
                    label: 'Photo',
                    color: Colors.purple,
                    onTap: () => Navigator.pop(context, 'photo'),
                  ),
                  _GalleryOption(
                    icon: Icons.videocam,
                    label: 'Vidéo',
                    color: Colors.blue,
                    onTap: () => Navigator.pop(context, 'video'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      );

      if (result == 'photo') {
        final XFile? image = await _picker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );
        
        if (image != null) {
          final file = File(image.path);
          await _sendRealMediaMessage('🖼️ Photo depuis la galerie', file);
        }
      } else if (result == 'video') {
        final XFile? video = await _picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(minutes: 5),
        );
        
        if (video != null) {
          final file = File(video.path);
          await _sendRealMediaMessage('🎥 Vidéo depuis la galerie', file);
        }
      }
    } catch (e) {
      _showSnackBar('❌ Erreur lors de l\'ouverture de la galerie');
    }
  }

  Future<void> _pickVideoFromGallery() async {
    try {
      final XFile? video = await _picker.pickVideo(
        source: ImageSource.gallery,
        maxDuration: const Duration(minutes: 5),
      );
      
      if (video != null) {
        final file = File(video.path);
        await _sendRealMediaMessage('🎥 Vidéo', file);
      }
    } catch (e) {
      _showSnackBar('❌ Erreur lors de la sélection de vidéo');
    }
  }

  Future<void> _pickDocument() async {
    try {
      _showSnackBar('📄 Document sélectionné (simulation)');
      await _sendMediaMessage('📄 Document.pdf', MediaType.text);
    } catch (e) {
      _showSnackBar('❌ Erreur lors de la sélection de document');
    }
  }

  Future<void> _sendRealMediaMessage(String content, File file) async {
    if (_isSending) return;

    setState(() {
      _isSending = true;
    });

    try {
      final fileSizeInMB = await file.length() / (1024 * 1024);
      
      if (fileSizeInMB > 10) {
        _showError('Fichier trop volumineux (max 10MB)');
        setState(() {
          _isSending = false;
        });
        return;
      }
      
      // 🎯 MESSAGE D'ENVOI PLUS DISCRET
      _showSnackBar('📤 Envoi en cours...', duration: 2);
      
      print('📤 [MEDIA] Début envoi: $content');
      print('📤 [MEDIA] Taille fichier: ${fileSizeInMB.toStringAsFixed(2)} MB');
      
      final response = await _messageService.sendMessage(
        widget.partnerId,
        content,
        mediaFile: file,
      );
      
      // ✅ VÉRIFIER QUE LA RÉPONSE EST VALIDE
      if (response?.data != null) {
        print('✅ [MEDIA] Fichier envoyé avec succès - ID: ${response!.data.id}');
        
        if (mounted) {
          setState(() {
            _isSending = false;
          });
          
          // 🎯 AJOUTER LE MESSAGE AVEC ANIMATION DOUCE
          _addMessageWithAnimation(response.data);
          
          // 🎯 MESSAGE DE SUCCÈS VERT
          _showSuccessMessage('Fichier envoyé avec succès', duration: 2);
        }
      } else {
        print('⚠️ [MEDIA] Réponse invalide, vérification...');
        
        if (mounted) {
          setState(() {
            _isSending = false;
          });
          
          // Vérifier si le fichier est apparu quand même
          await Future.delayed(const Duration(milliseconds: 2000));
          final oldCount = _messages.length;
          await _loadMessages();
          
          if (_messages.length > oldCount) {
            _showSuccessMessage('Fichier envoyé', duration: 2);
          } else {
            _showError('Échec de l\'envoi du fichier');
          }
        }
      }
      
    } catch (e) {
      print('❌ [MEDIA] Exception lors de l\'envoi: $e');
      
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        
        // 🔧 ANALYSE DE L'ERREUR POUR DONNER UN MESSAGE PRÉCIS
        String errorMessage = 'Erreur lors de l\'envoi du fichier';
        String errorString = e.toString().toLowerCase();
        
        if (errorString.contains('socketexception') || errorString.contains('network')) {
          errorMessage = 'Problème de connexion réseau';
        } else if (errorString.contains('timeout')) {
          errorMessage = 'Délai d\'attente dépassé (fichier trop volumineux?)';
        } else if (errorString.contains('413')) {
          errorMessage = 'Fichier trop volumineux pour le serveur';
        } else if (errorString.contains('415')) {
          errorMessage = 'Type de fichier non supporté';
        } else if (errorString.contains('507')) {
          errorMessage = 'Espace serveur insuffisant';
        } else {
          // Vérifier si le fichier est passé malgré l'erreur
          print('🔍 [MEDIA] Vérification post-erreur...');
          await Future.delayed(const Duration(milliseconds: 2000));
          final oldCount = _messages.length;
          await _loadMessages();
          
          if (_messages.length > oldCount) {
            _showSuccessMessage('Fichier envoyé malgré l\'erreur', duration: 2);
            return;
          }
        }
        
        print('📢 [MEDIA] Message d\'erreur utilisateur: $errorMessage');
        _showError(errorMessage);
      }
    }
  }

  Future<void> _sendMediaMessage(String content, MediaType mediaType, {String? mediaUrl, File? file}) async {
    if (file != null) {
      await _sendRealMediaMessage(content, file);
    } else {
      if (_isSending) return;

      setState(() {
        _isSending = true;
      });

      try {
        final response = await _messageService.sendMessage(
          widget.partnerId,
          content,
        );
        
        if (mounted) {
          setState(() {
            _messages.add(response.data);
            _isSending = false;
          });
          
          _scrollToBottom();
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isSending = false;
          });
          
          _showError('Erreur lors de l\'envoi du message');
        }
      }
    }
  }

  Future<bool> _checkMicrophonePermission() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showSnackBar('❌ Permission microphone refusée');
      return false;
    }
    return true;
  }

  // 🎤 NOUVELLES MÉTHODES POUR LE SYSTÈME CLIC & ENVOYER

  // ✅ 1. DÉMARRER L'ENREGISTREMENT (CLIC SIMPLE)
  void _startRecordingClick() async {
    try {
      final hasPermission = await _checkMicrophonePermission();
      if (!hasPermission) return;
      
      final directory = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${directory.path}/recording_$timestamp.m4a';
      
      await _audioRecorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: _currentRecordingPath!,
      );
      
      setState(() {
        _isRecording = true;
        _recordingFinished = false;
        _recordingDuration = Duration.zero;
      });
      
      _recordingAnimationController.repeat(reverse: true);
      HapticFeedback.mediumImpact();
      
      _startRecordingTimer();
      
      _showSnackBar('🎤 Enregistrement en cours...');
    } catch (e) {
      _showSnackBar('❌ Erreur lors du démarrage de l\'enregistrement');
    }
  }

  // ✅ 2. ARRÊTER L'ENREGISTREMENT (SANS ENVOYER)
  void _stopRecordingClick() async {
    try {
      final path = await _audioRecorder.stop();
      
      _recordingTimer?.cancel();
      _recordingAnimationController.stop();
      
      if (_recordingDuration.inSeconds < 1) {
        _showSnackBar('⚠️ Enregistrement trop court');
        if (path != null && File(path).existsSync()) {
          File(path).deleteSync();
        }
        setState(() {
          _isRecording = false;
          _recordingFinished = false;
          _currentRecordingPath = null;
        });
        return;
      }
      
      if (path != null && File(path).existsSync()) {
        setState(() {
          _recordingFinished = true; // Marquer comme terminé
          _currentRecordingPath = path; // Sauvegarder le chemin
        });
        _showSnackBar('🎤 Enregistrement prêt à envoyer');
      } else {
        _showSnackBar('❌ Erreur lors de l\'enregistrement');
        setState(() {
          _isRecording = false;
          _recordingFinished = false;
          _currentRecordingPath = null;
        });
      }
    } catch (e) {
      _showSnackBar('❌ Erreur lors de l\'arrêt de l\'enregistrement');
      setState(() {
        _isRecording = false;
        _recordingFinished = false;
        _currentRecordingPath = null;
      });
    }
  }

  // ✅ 3. ENVOYER L'ENREGISTREMENT
  void _sendRecordingClick() async {
    if (_currentRecordingPath == null) return;
    
    try {
      final audioFile = File(_currentRecordingPath!);
      
      if (!audioFile.existsSync()) {
        _showSnackBar('❌ Fichier audio non trouvé');
        return;
      }
      
      final durationText = '${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}';
      
      _showSnackBar('⏳ Envoi du message vocal...');
      
      final response = await _messageService.sendMessage(
        widget.partnerId,
        '🎤 Message vocal ($durationText)',
        mediaFile: audioFile,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(response.data);
          _isRecording = false; // Réinitialiser l'état
          _recordingFinished = false;
          _currentRecordingPath = null;
          _recordingDuration = Duration.zero;
        });
        
        _scrollToBottom();
        _showSnackBar('🎤 Message vocal envoyé ($durationText)');
        
        if (audioFile.existsSync()) {
          audioFile.deleteSync();
        }
      }
    } catch (e) {
      _showSnackBar('❌ Erreur lors de l\'envoi du message vocal');
      setState(() {
        _isRecording = false;
        _recordingFinished = false;
        _currentRecordingPath = null;
        _recordingDuration = Duration.zero;
      });
    }
  }

  // ✅ 4. ANNULER L'ENREGISTREMENT
  void _cancelRecordingClick() {
    try {
      if (_currentRecordingPath != null && File(_currentRecordingPath!).existsSync()) {
        File(_currentRecordingPath!).deleteSync();
      }
      
      setState(() {
        _isRecording = false;
        _recordingFinished = false;
        _currentRecordingPath = null;
        _recordingDuration = Duration.zero;
      });
      
      _recordingTimer?.cancel();
      _recordingAnimationController.stop();
      
      _showSnackBar('🗑️ Enregistrement annulé');
    } catch (e) {
      _showSnackBar('🗑️ Enregistrement annulé');
    }
  }

  void _startRecordingTimer() {
    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!_isRecording) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _recordingDuration = Duration(seconds: _recordingDuration.inSeconds + 1);
      });
      
      if (_recordingDuration.inSeconds >= 60) {
        _stopRecordingClick();
        timer.cancel();
      }
    });
  }

  Future<void> _playVoiceMessage(String audioUrl) async {
    try {
      _showSnackBar('🔊 Lecture en cours...');
      
      await _audioPlayer.play(UrlSource(audioUrl));
      
      _audioPlayer.onPlayerComplete.listen((event) {
        _showSnackBar('✅ Lecture terminée');
      });
    } catch (e) {
      _showSnackBar('❌ Erreur lors de la lecture');
    }
  }

  // 🆕 MÉTHODE POUR AFFICHER LES DÉTAILS DE LA COMMANDE
  void _showOrderDetails() {
    if (widget.orderContext == null) return;
    
    final order = widget.orderContext!;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.receipt_long, color: primaryColor),
            const SizedBox(width: 8),
            Text('Commande #${order.id}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _getStatusColor(order.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _getStatusColor(order.status)),
                ),
                child: Text(
                  order.status.displayName,
                  style: TextStyle(
                    color: _getStatusColor(order.status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              _buildDetailRow('Total', order.formattedTotalAmount),
              _buildDetailRow('Articles', '${order.itemsCount} article(s)'),
              _buildDetailRow('Date', _formatDate(order.createdAt)),
              
              const SizedBox(height: 16),
              const Text(
                'Articles commandés :',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              
              ...order.orderItems.map((item) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: item.product.firstImageUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                item.product.firstImageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.shopping_bag,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.shopping_bag,
                              color: Colors.grey,
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.product.name,
                            style: const TextStyle(fontWeight: FontWeight.w500),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Quantité: ${item.quantity} × ${item.product.formattedPrice}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      item.formattedTotalPrice,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: primaryColor,
                      ),
                    ),
                  ],
                ),
              )).toList(),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          if (order.status == OrderStatus.pending)
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _sendOrderReminderMessage();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Envoyer rappel'),
            ),
        ],
      ),
    );
  }

  // 🆕 MÉTHODE POUR ENVOYER UN RAPPEL DE COMMANDE
  void _sendOrderReminderMessage() {
    if (widget.orderContext == null) return;
    
    final order = widget.orderContext!;
    final reminderMessage = '''🔔 Rappel de commande

Bonjour ! Je vous relance concernant ma commande #${order.formattedOrderNumber}.

📝 Détails :
${order.orderItems.map((item) => '• ${item.product.name} (x${item.quantity})').join('\n')}

💰 Total : ${order.formattedTotalAmount}
📅 Passée le : ${_formatDate(order.createdAt)}

Pouvez-vous me donner des nouvelles de l'état de ma commande ?

Merci ! 😊''';

    setState(() {
      _messageController.text = reminderMessage;
      _isTyping = true;
    });
    
    _showSnackBar('💬 Message de rappel prêt à envoyer');
  }

  // 🆕 MÉTHODES UTILITAIRES POUR LES COMMANDES
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(color: Colors.grey[600]),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.shipped:
        return Colors.purple;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.canceled:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        if (animate) {
          // 🎯 ANIMATION PLUS DOUCE ET PLUS LENTE
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 800), // Plus lent
            curve: Curves.easeOutCubic, // Courbe plus naturelle
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    });
  }

  // 🎯 NOUVELLE MÉTHODE POUR AJOUTER UN MESSAGE AVEC ANIMATION
  void _addMessageWithAnimation(Message message) {
    if (!mounted) return;
    
    setState(() {
      _messages.add(message);
    });
    
    // 🎯 DÉLAI PLUS COURT POUR L'ANIMATION DE SCROLL
    Future.delayed(const Duration(milliseconds: 300), () {
      _scrollToBottom();
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // 🎯 NOUVELLE MÉTHODE POUR LES MESSAGES DE SUCCÈS VERTS
  void _showSuccessMessage(String message, {int duration = 2}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[600],
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: duration),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSnackBar(String message, {int duration = 2}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryColor,
        duration: Duration(seconds: duration),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _AttachmentOption(
                  icon: Icons.photo_camera,
                  label: 'Appareil photo',
                  color: Colors.pink,
                  onTap: () {
                    Navigator.pop(context);
                    _takePicture();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.photo_library,
                  label: 'Galerie',
                  color: Colors.purple,
                  onTap: () {
                    Navigator.pop(context);
                    _pickImageFromGallery();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.videocam,
                  label: 'Vidéo',
                  color: Colors.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _pickVideoFromGallery();
                  },
                ),
                _AttachmentOption(
                  icon: Icons.insert_drive_file,
                  label: 'Document',
                  color: Colors.orange,
                  onTap: () {
                    Navigator.pop(context);
                    _pickDocument();
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFECE5DD),
      appBar: _buildAppBar(),
      body: Column(
        children: [
          // 🆕 INDICATEUR D'ENVOI D'IMAGES DE COMMANDE
          if (_isSendingOrderImages)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                border: Border(
                  bottom: BorderSide(color: primaryColor.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: primaryColor,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    '📸 Envoi des images de produits en cours...',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          
          Expanded(
            child: _isLoading
                ? Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  )
                : RefreshIndicator(
                    onRefresh: _loadMessages,
                    color: primaryColor,
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _visibleMessages.length,
                      itemBuilder: (context, index) {
                        final message = _visibleMessages[index];
                        
                        // 🎯 ANIMATION DOUCE SEULEMENT POUR LES NOUVEAUX MESSAGES
                        final isNewMessage = index == _visibleMessages.length - 1 && 
                                            _messages.length > 1;
                        
                        Widget messageBubble = _MessageBubble(
                          message: message,
                          isFromCurrentUser: _isMessageFromCurrentUser(message),
                          onEdit: () => _editMessage(message),
                          onDeleteForMe: () => _deleteMessageForMe(message),
                          onDeleteForEveryone: () => _deleteMessageForEveryone(message),
                          onPlayVoice: (url) => _playVoiceMessage(url),
                          canDeleteForEveryone: _canDeleteForEveryone(message),
                        );
                        
                        if (isNewMessage) {
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 600),
                            curve: Curves.easeOutCubic,
                            transform: Matrix4.translationValues(0, 0, 0),
                            child: AnimatedOpacity(
                              duration: const Duration(milliseconds: 400),
                              opacity: 1.0,
                              child: messageBubble,
                            ),
                          );
                        }
                        
                        return messageBubble;
                      },
                    ),
                  ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  // 🔧 APPBAR AVEC INDICATEUR EN LIGNE
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.white),
        onPressed: () => Navigator.pop(context),
      ),
      title: Row(
        children: [
          Stack(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.white,
                backgroundImage: widget.partnerPhoto != null 
                    ? NetworkImage(widget.partnerPhoto!)
                    : null,
                child: widget.partnerPhoto == null
                    ? Text(
                        widget.partnerName[0].toUpperCase(),
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                    : null,
              ),
              // 🆕 INDICATEUR EN LIGNE
              if (widget.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: Colors.green,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.partnerName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  widget.isOnline ? 'En ligne' : 'Vu récemment',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // 🆕 BOUTON POUR VOIR LES DÉTAILS DE LA COMMANDE
        if (widget.orderContext != null)
          IconButton(
            icon: const Icon(Icons.receipt_long, color: Colors.white),
            onPressed: () => _showOrderDetails(),
          ),
        
        IconButton(
          icon: const Icon(Icons.videocam, color: Colors.white),
          onPressed: () => _showSnackBar('Appel vidéo'),
        ),
        IconButton(
          icon: const Icon(Icons.call, color: Colors.white),
          onPressed: () => _showSnackBar('Appel vocal'),
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () => _showSnackBar('Plus d\'options'),
        ),
        
        // 🐛 BOUTON DEBUG (retirez en production)
        IconButton(
          icon: const Icon(Icons.bug_report, color: Colors.white70, size: 20),
          onPressed: _showDebugInfo,
          tooltip: 'Informations de débogage',
        ),
      ],
      // 🆕 BANNIÈRE POUR INDIQUER LE CONTEXTE COMMANDE
      bottom: widget.orderContext != null ? PreferredSize(
        preferredSize: const Size.fromHeight(50),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(
              top: BorderSide(color: Colors.white.withOpacity(0.3)),
            ),
          ),
          child: Row(
            children: [
              const Icon(Icons.shopping_cart, size: 18, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Commande #${widget.orderContext!.formattedOrderNumber} - ${widget.orderContext!.formattedTotalAmount}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _showOrderDetails,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Détails',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ) : null,
    );
  }

  // 🎨 NOUVELLE INTERFACE DE SAISIE AVEC SYSTÈME CLIC & ENVOYER
  Widget _buildMessageInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Column(
        children: [
          // 🎤 Interface d'enregistrement - NOUVELLE VERSION
          if (_isRecording) 
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red[200]!),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _recordingFinished 
                          ? 'Enregistrement terminé ${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}'
                          : 'Enregistrement... ${_recordingDuration.inMinutes}:${(_recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const Spacer(),
                      // Animation des ondes sonores (seulement si en cours)
                      if (!_recordingFinished)
                        Row(
                          children: List.generate(3, (index) => 
                            AnimatedBuilder(
                              animation: _recordingAnimation,
                              builder: (context, child) {
                                return Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 1),
                                  height: 4 + (_recordingAnimation.value * 8),
                                  width: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.red,
                                    borderRadius: BorderRadius.circular(1),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Bouton Annuler
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _cancelRecordingClick,
                          icon: const Icon(Icons.delete_outline, color: Colors.red),
                          label: const Text('Annuler', style: TextStyle(color: Colors.red)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Bouton Stop ou Envoyer
                      Expanded(
                        child: !_recordingFinished 
                          ? // Encore en train d'enregistrer
                            ElevatedButton.icon(
                              onPressed: _stopRecordingClick,
                              icon: const Icon(Icons.stop, color: Colors.white),
                              label: const Text('Stop', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            )
                          : // Enregistrement terminé, prêt à envoyer
                            ElevatedButton.icon(
                              onPressed: _sendRecordingClick,
                              icon: const Icon(Icons.send, color: Colors.white),
                              label: const Text('Envoyer', style: TextStyle(color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: primaryColor,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                            ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          
          // 💬 Interface normale
          if (!_isRecording) 
            Row(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          icon: Icon(
                            _showEmojiPicker ? Icons.keyboard : Icons.emoji_emotions,
                            color: Colors.grey[600],
                          ),
                          onPressed: () {
                            setState(() {
                              _showEmojiPicker = !_showEmojiPicker;
                            });
                            if (_showEmojiPicker) {
                              _focusNode.unfocus();
                            } else {
                              _focusNode.requestFocus();
                            }
                          },
                        ),
                        Expanded(
                          child: TextField(
                            controller: _messageController,
                            focusNode: _focusNode,
                            decoration: const InputDecoration(
                              hintText: 'Tapez un message...',
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 12),
                            ),
                            maxLines: 4,
                            minLines: 1,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: (_) => _sendMessage(),
                            enabled: !_isSendingOrderImages,
                          ),
                        ),
                        IconButton(
                          icon: Icon(
                            Icons.attach_file,
                            color: _isSendingOrderImages ? Colors.grey[400] : Colors.grey[600],
                          ),
                          onPressed: _isSendingOrderImages ? null : _showAttachmentOptions,
                        ),
                        if (!_isTyping)
                          IconButton(
                            icon: Icon(
                              Icons.camera_alt,
                              color: _isSendingOrderImages ? Colors.grey[400] : Colors.grey[600],
                            ),
                            onPressed: _isSendingOrderImages ? null : _takePicture,
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                
                // 🎯 BOUTON PRINCIPAL - NOUVEAU SYSTÈME CLIC SIMPLE
                GestureDetector(
                  onTap: () {
                    if (_isTyping && !_isSendingOrderImages) {
                      _sendMessage();
                    } else if (!_isSendingOrderImages) {
                      _startRecordingClick(); // 🎤 CLIC SIMPLE POUR DÉMARRER
                    }
                  },
                  child: Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: _isSendingOrderImages 
                          ? Colors.grey[400] 
                          : primaryColor,
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: (_isSending || _isSendingOrderImages)
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            _isTyping ? Icons.send : Icons.mic,
                            color: Colors.white,
                            size: 24,
                          ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  bool _isMessageFromCurrentUser(Message message) {
    return message.senderId != widget.partnerId;
  }
}

// 🔧 WIDGET MESSAGE BUBBLE AVEC LIMITE 30 MINUTES
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isFromCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback onDeleteForMe;
  final VoidCallback onDeleteForEveryone;
  final Function(String) onPlayVoice;
  final bool canDeleteForEveryone; // 🕰️ NOUVEAU PARAMÈTRE

  const _MessageBubble({
    required this.message,
    required this.isFromCurrentUser,
    required this.onEdit,
    required this.onDeleteForMe,
    required this.onDeleteForEveryone,
    required this.onPlayVoice,
    required this.canDeleteForEveryone, // 🕰️ NOUVEAU PARAMÈTRE
  });

  static const Color primaryColor = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      child: Row(
        mainAxisAlignment: isFromCurrentUser 
            ? MainAxisAlignment.end 
            : MainAxisAlignment.start,
        children: [
          if (!isFromCurrentUser) ...[
            const CircleAvatar(
              radius: 12,
              backgroundColor: Colors.grey,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: GestureDetector(
              onLongPress: () => _showMessageOptions(context),
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.75,
                ),
                decoration: BoxDecoration(
                  color: isFromCurrentUser 
                      ? primaryColor
                      : Colors.white,
                  borderRadius: BorderRadius.only(
                    topLeft: const Radius.circular(12),
                    topRight: const Radius.circular(12),
                    bottomLeft: Radius.circular(
                      isFromCurrentUser ? 12 : 4,
                    ),
                    bottomRight: Radius.circular(
                      isFromCurrentUser ? 4 : 12,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 2,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMessageContent(),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          _formatTime(message.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isFromCurrentUser ? Colors.white70 : Colors.grey[600],
                          ),
                        ),
                        if (isFromCurrentUser) ...[
                          const SizedBox(width: 4),
                          Icon(
                            message.isRead ? Icons.done_all : Icons.done,
                            size: 16,
                            color: message.isRead 
                                ? Colors.white
                                : Colors.white70,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (isFromCurrentUser) ...[
            const SizedBox(width: 8),
            const CircleAvatar(
              radius: 12,
              backgroundColor: primaryColor,
              child: Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  // 🕰️ OPTIONS DE MESSAGE AVEC VÉRIFICATION 30 MINUTES
  void _showMessageOptions(BuildContext context) {
    // 🆕 NE PAS AFFICHER D'OPTIONS POUR LES MESSAGES SUPPRIMÉS
    if (message.deletedForEveryone) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ Aucune action possible sur un message supprimé'),
          backgroundColor: Colors.grey,
        ),
      );
      return;
    }
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            
            if (isFromCurrentUser && message.mediaType == MediaType.text) ...[
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('✏️ Modifier'),
                onTap: () {
                  Navigator.pop(context);
                  onEdit();
                },
              ),
            ],
            
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.orange),
              title: const Text('🗑️ Supprimer pour moi'),
              onTap: () {
                Navigator.pop(context);
                onDeleteForMe();
              },
            ),
            
            // 🕰️ AFFICHER "SUPPRIMER POUR TOUT LE MONDE" SELON L'ÂGE
            if (isFromCurrentUser) ...[
              if (canDeleteForEveryone) 
                ListTile(
                  leading: const Icon(Icons.delete_forever, color: Colors.red),
                  title: const Text('🗑️ Supprimer pour tout le monde'),
                  onTap: () {
                    Navigator.pop(context);
                    onDeleteForEveryone();
                  },
                )
              else
                ListTile(
                  leading: Icon(Icons.access_time, color: Colors.grey[400]),
                  title: Text(
                    '🕰️ Limite de 30 min dépassée',
                    style: TextStyle(color: Colors.grey[500], fontStyle: FontStyle.italic),
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('⏰ Vous ne pouvez plus supprimer ce message pour tout le monde. La limite de 30 minutes est dépassée.'),
                        backgroundColor: Colors.orange,
                        duration: Duration(seconds: 3),
                      ),
                    );
                  },
                ),
            ],
            
            if (message.mediaType == MediaType.text && !message.deletedForEveryone) ...[
              ListTile(
                leading: const Icon(Icons.copy, color: Colors.grey),
                title: const Text('📋 Copier'),
                onTap: () {
                  Navigator.pop(context);
                  Clipboard.setData(ClipboardData(text: message.content));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('📋 Message copié'),
                      backgroundColor: primaryColor,
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  // 🔧 CONTENU DE MESSAGE CORRIGÉ AVEC SUPPORT SUPPRESSION
  Widget _buildMessageContent() {
    // 🆕 VÉRIFIER SI LE MESSAGE EST SUPPRIMÉ POUR TOUT LE MONDE
    if (message.deletedForEveryone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: 16,
              color: isFromCurrentUser ? Colors.white70 : Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Text(
              'Ce message a été supprimé',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isFromCurrentUser ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }
    
    if (message.content.contains('🎤 Message vocal')) {
      return _buildVoiceMessageWidget();
    }
    
    switch (message.mediaType) {
      case MediaType.image:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                width: 200,
                height: 150,
                color: Colors.grey[300],
                child: message.mediaUrl != null
                    ? Image.network(
                        message.mediaUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[300],
                            child: const Icon(
                              Icons.image,
                              size: 50,
                              color: Colors.grey,
                            ),
                          );
                        },
                      )
                    : const Icon(
                        Icons.image,
                        size: 50,
                        color: Colors.grey,
                      ),
              ),
            ),
            if (message.content.isNotEmpty && message.content != "📸 Photo")
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  message.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: isFromCurrentUser ? Colors.white : Colors.black,
                  ),
                ),
              ),
          ],
        );
        
      case MediaType.video:
        return Container(
          width: 200,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Stack(
            alignment: Alignment.center,
            children: [
              Icon(
                Icons.play_circle_filled,
                size: 50,
                color: Colors.white,
              ),
              Positioned(
                bottom: 8,
                right: 8,
                child: Text(
                  '2:34',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
        
      case MediaType.audio:
        return _buildVoiceMessageWidget();
        
      default:
        return Text(
          message.content,
          style: TextStyle(
            fontSize: 16,
            color: isFromCurrentUser ? Colors.white : Colors.black,
          ),
        );
    }
  }

  // 🔧 WIDGET MESSAGE VOCAL CORRIGÉ
  Widget _buildVoiceMessageWidget() {
    // 🆕 SI LE MESSAGE EST SUPPRIMÉ, NE PAS AFFICHER LE LECTEUR AUDIO
    if (message.deletedForEveryone) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.block,
              size: 16,
              color: isFromCurrentUser ? Colors.white70 : Colors.grey[500],
            ),
            const SizedBox(width: 8),
            Text(
              'Ce message a été supprimé',
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: isFromCurrentUser ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    final durationText = message.content.contains('(') 
        ? message.content.split('(')[1].split(')')[0] 
        : '0:00';
    
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isFromCurrentUser 
              ? primaryColor.withOpacity(0.1)
              : Colors.grey[100],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isFromCurrentUser 
                ? primaryColor
                : Colors.grey[300]!,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GestureDetector(
              onTap: () {
                if (message.mediaUrl != null) {
                  onPlayVoice(message.mediaUrl!);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('❌ Fichier audio non disponible'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: primaryColor,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '🎤 Message vocal',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isFromCurrentUser ? Colors.black : Colors.black,
                  ),
                ),
                Text(
                  durationText,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// WIDGET POUR OPTIONS D'ATTACHEMENT
class _AttachmentOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// WIDGET POUR OPTIONS DE GALERIE
class _GalleryOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _GalleryOption({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 40,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}