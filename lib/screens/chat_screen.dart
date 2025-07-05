// lib/screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;

import '../models/message_model.dart';
import '../models/order_model.dart';
import '../services/message_service.dart';
import '../constants/app_colors.dart';

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

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _focusNode = FocusNode();
  
  final MessageService _messageService = MessageService();
  final ImagePicker _picker = ImagePicker();
  
  bool _isTyping = false;
  bool _showEmojiPicker = false;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSendingOrderImages = false;
  
  List<Message> _messages = [];
  Partner? _partner;
  int? _currentUserId;

  static const Color primaryColor = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    
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
      final response = await _messageService.sendMessage(
        widget.partnerId,
        text,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(response.data);
          _messageController.clear();
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

  // 🆕 MÉTHODE POUR ENVOYER COMMANDE + IMAGES
  /// 🆕 MÉTHODE UTILITAIRE : Envoyer un message texte simple
Future<void> _sendTextMessage(String content) async {
  try {
    final response = await _messageService.sendMessage(
      widget.partnerId,
      content,
    );
    
    if (mounted) {
      setState(() {
        _messages.add(response.data);
      });
      _scrollToBottom();
    }
  } catch (e) {
    print('❌ [TEXT_MESSAGE] Erreur envoi texte: $e');
  }
}

/// 🛒 Envoyer commande + images SEULEMENT du marchand concerné - VERSION SIMPLIFIÉE
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
      await Future.delayed(const Duration(milliseconds: 1000));
    }
    
    // 🎯 2. FILTRER LES PRODUITS AVEC IMAGES POUR CE MARCHAND SEULEMENT
    final productsWithImages = order.orderItems
        .where((item) => item.product.firstImageUrl.isNotEmpty)
        .toList();
    
    if (productsWithImages.isNotEmpty) {
      _showSnackBar('📸 Envoi de ${productsWithImages.length} image(s) de vos produit(s)...', duration: 3);
      
      // 3. ENVOYER LES IMAGES UNE PAR UNE
      for (int i = 0; i < productsWithImages.length; i++) {
        final item = productsWithImages[i];
        
        try {
          await _sendProductImageAsMedia(item, i + 1, productsWithImages.length);
          
          // Pause entre chaque image
          if (i < productsWithImages.length - 1) {
            await Future.delayed(const Duration(milliseconds: 1200));
          }
        } catch (e) {
          print('❌ [ORDER_IMAGE] Erreur pour ${item.product.name}: $e');
        }
      }
      
      _showSnackBar('✅ ${productsWithImages.length} image(s) envoyée(s) avec succès !');
    } else {
      _showSnackBar('ℹ️ Aucune image de produit à envoyer');
    }
    
  } catch (e) {
    print('❌ [ORDER_IMAGES] Erreur générale: $e');
    _showSnackBar('⚠️ Erreur lors de l\'envoi des images');
  } finally {
    if (mounted) {
      setState(() {
        _isSendingOrderImages = false;
      });
    }
  }
}

/// 🆕 NOUVELLE MÉTHODE : Envoyer l'image d'un produit comme VRAIE image média - VERSION SIMPLIFIÉE
Future<void> _sendProductImageAsMedia(OrderItem item, int currentIndex, int totalImages) async{
  try {
    print('📸 [PRODUCT_IMAGE] [$currentIndex/$totalImages] Envoi image: ${item.product.name}');
    print('📸 [PRODUCT_IMAGE] URL: ${item.product.firstImageUrl}');
    
    // 🔧 UTILISER VOTRE MÉTHODE EXISTANTE
    final imageFile = await _downloadImageFromUrl(item.product.firstImageUrl);
    
    if (imageFile != null) {
      // 🔧 ÉTAPE 1 : Envoyer le titre/description en texte DIRECTEMENT
      final productDescription = '''📦 **${item.product.name}**
💰 ${item.product.formattedPrice} × ${item.quantity} = ${item.formattedTotalPrice}''';
      
      try {
        final textResponse = await _messageService.sendMessage(
          widget.partnerId,
          productDescription,
        );
        
        if (mounted) {
          setState(() {
            _messages.add(textResponse.data);
          });
          _scrollToBottom();
        }
      } catch (e) {
        print('❌ Erreur envoi texte: $e');
      }
      
      // Petite pause entre le texte et l'image
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 🔧 ÉTAPE 2 : Envoyer l'image comme média (SANS texte)
      try {
        final imageResponse = await _messageService.sendMessage(
          widget.partnerId,
          '', // 🔧 Message vide pour que ce soit juste l'image
          mediaFile: imageFile,
        );
        
        if (mounted) {
          setState(() {
            _messages.add(imageResponse.data);
          });
          
          _scrollToBottom();
          print('✅ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Image envoyée: ${item.product.name}');
        }
      } catch (e) {
        print('❌ Erreur envoi image: $e');
      }
      
      // 🔧 NETTOYER le fichier temporaire
      if (await imageFile.exists()) {
        await imageFile.delete();
      }
    } else {
      print('❌ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Échec téléchargement: ${item.product.name}');
      
      // 🔧 FALLBACK : Envoyer au moins le texte avec l'URL DIRECTEMENT
      final fallbackMessage = '''📦 ${item.product.name} (x${item.quantity})
💰 ${item.formattedTotalPrice}
🖼️ Image : ${item.product.firstImageUrl}''';
      
      try {
        final fallbackResponse = await _messageService.sendMessage(
          widget.partnerId,
          fallbackMessage,
        );
        
        if (mounted) {
          setState(() {
            _messages.add(fallbackResponse.data);
          });
          _scrollToBottom();
        }
      } catch (e) {
        print('❌ Erreur envoi fallback: $e');
      }
    }
  } catch (e) {
    print('❌ [PRODUCT_IMAGE] [$currentIndex/$totalImages] Exception ${item.product.name}: $e');
    
    // 🔧 FALLBACK EN CAS D'ERREUR GÉNÉRALE
    final errorMessage = '''📦 ${item.product.name} (x${item.quantity})
💰 ${item.formattedTotalPrice}
⚠️ Erreur lors de l'envoi de l'image''';
    
    try {
      final errorResponse = await _messageService.sendMessage(
        widget.partnerId,
        errorMessage,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(errorResponse.data);
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('❌ Erreur envoi message d\'erreur: $e');
    }
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
        const Duration(seconds: 10),
      );
      
      if (response.statusCode == 200) {
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
        print('❌ [DOWNLOAD] Erreur HTTP ${response.statusCode}');
        return null;
      }
    } catch (e) {
      print('❌ [DOWNLOAD] Exception: $e');
      return null;
    }
  }

  // 🆕 CONSTRUIRE L'URL COMPLÈTE DE L'IMAGE
  String _buildFullImageUrl(String imageUrl) {
    // Si l'URL est déjà complète (contient http), la retourner telle quelle
    if (imageUrl.startsWith('http://') || imageUrl.startsWith('https://')) {
      return imageUrl;
    }
    
    // 🔧 REMPLACEZ CETTE URL PAR CELLE DE VOTRE SERVEUR
    const String baseUrl = 'http://192.168.1.100:3000'; // 📝 MODIFIEZ ICI !
    // Ou utilisez votre domaine : 'https://monapi.com'
    
    // Supprimer le slash initial si présent pour éviter les doubles slashes
    String cleanPath = imageUrl.startsWith('/') ? imageUrl.substring(1) : imageUrl;
    
    // Construire l'URL complète
    return '$baseUrl/$cleanPath';
  }

  // 🆕 GÉNÉRER UNE CHAÎNE ALÉATOIRE POUR LES NOMS DE FICHIERS
  String _generateRandomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().millisecond % chars.length]).join();
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
        _showSnackBar('❌ Fichier trop volumineux (max 10MB)');
        setState(() {
          _isSending = false;
        });
        return;
      }
      
      _showSnackBar('⏳ Envoi en cours...');
      
      final response = await _messageService.sendMessage(
        widget.partnerId,
        content,
        mediaFile: file,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(response.data);
          _isSending = false;
        });
        
        _scrollToBottom();
        _showSnackBar('✅ $content envoyé avec succès');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        
        _showSnackBar('❌ Erreur lors de l\'envoi du fichier');
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSnackBar(String message, {int duration = 2}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryColor,
        duration: Duration(seconds: duration),
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
                        return _MessageBubble(
                          message: message,
                          isFromCurrentUser: _isMessageFromCurrentUser(message),
                          onEdit: () => _editMessage(message),
                          onDeleteForMe: () => _deleteMessageForMe(message),
                          onDeleteForEveryone: () => _deleteMessageForEveryone(message),
                          canDeleteForEveryone: _canDeleteForEveryone(message),
                        );
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

  // 🎨 INTERFACE DE SAISIE SIMPLIFIÉE (SANS AUDIO)
  Widget _buildMessageInput() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
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
          
          // 🎯 BOUTON D'ENVOI SIMPLIFIÉ
          GestureDetector(
            onTap: () {
              if (_isTyping && !_isSendingOrderImages) {
                _sendMessage();
              }
            },
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: _isSendingOrderImages 
                    ? Colors.grey[400] 
                    : (_isTyping ? primaryColor : Colors.grey[400]),
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
                      Icons.send,
                      color: Colors.white,
                      size: 24,
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isMessageFromCurrentUser(Message message) {
    return message.senderId != widget.partnerId;
  }
}

// 🔧 WIDGET MESSAGE BUBBLE SANS AUDIO
class _MessageBubble extends StatelessWidget {
  final Message message;
  final bool isFromCurrentUser;
  final VoidCallback onEdit;
  final VoidCallback onDeleteForMe;
  final VoidCallback onDeleteForEveryone;
  final bool canDeleteForEveryone;

  const _MessageBubble({
    required this.message,
    required this.isFromCurrentUser,
    required this.onEdit,
    required this.onDeleteForMe,
    required this.onDeleteForEveryone,
    required this.canDeleteForEveryone,
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

  void _showMessageOptions(BuildContext context) {
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

  Widget _buildMessageContent() {
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