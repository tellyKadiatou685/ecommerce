// lib/screens/conversations_screen.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message_model.dart';
import '../services/message_service.dart';
import 'chat_screen.dart' as chat; // Import avec alias pour éviter le conflit

class ConversationsScreen extends StatefulWidget {
  const ConversationsScreen({Key? key}) : super(key: key);

  @override
  State<ConversationsScreen> createState() => _ConversationsScreenState();
}

class _ConversationsScreenState extends State<ConversationsScreen> {
  final TextEditingController _searchController = TextEditingController();
  final MessageService _messageService = MessageService();
  
  // 🔥 CHANGEMENT : Utiliser les vrais modèles de l'API
  List<Conversation> _conversations = [];
  List<Conversation> _filteredConversations = [];
  
  bool _isLoading = true;
  String? _errorMessage;
  int? _currentUserId;

  // 🔥 COULEUR COHÉRENTE AVEC CHATSCREEN
  static const Color primaryColor = Color(0xFFFF6B35);

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterConversations);
    _initializeConversations();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // 🔥 NOUVELLE MÉTHODE : Initialisation avec API
  Future<void> _initializeConversations() async {
    await _getCurrentUserId();
    await _loadConversations();
  }

  // 🔥 NOUVELLE MÉTHODE : Récupérer l'ID utilisateur actuel
  Future<void> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getInt('current_user_id');
      
      if (_currentUserId == null) {
        _currentUserId = 13; // Valeur par défaut
        await prefs.setInt('current_user_id', _currentUserId!);
      }
      
      print('🔍 [CONVERSATIONS] ID utilisateur actuel: $_currentUserId');
      
    } catch (e) {
      print('❌ [CONVERSATIONS] Erreur récupération ID utilisateur: $e');
      _currentUserId = 13;
    }
  }

  // 🔥 NOUVELLE MÉTHODE : Charger les conversations depuis l'API
  Future<void> _loadConversations() async {
    try {
      print('🔄 [CONVERSATIONS] Chargement des conversations...');
      
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await _messageService.getConversations();
      
      if (mounted) {
        setState(() {
          _conversations = response.data;
          _filteredConversations = response.data;
          _isLoading = false;
        });
        
        print('✅ [CONVERSATIONS] ${_conversations.length} conversations chargées');
      }
    } catch (e) {
      print('❌ [CONVERSATIONS] Erreur chargement: $e');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Erreur lors du chargement des conversations';
        });
        
        // 🔥 FALLBACK : Utiliser les données statiques en cas d'erreur
        _loadStaticConversations();
      }
    }
  }

  // 🔥 MÉTHODE FALLBACK : Charger les données statiques
  void _loadStaticConversations() {
    final staticConversations = [
      Conversation(
        partnerId: 1,
        partnerName: "Marie Dubois",
        partnerPhoto: "https://i.pravatar.cc/150?img=1",
        partnerRole: "user",
        lastMessage: "Salut ! Comment ça va ?",
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 5)),
        unreadCount: 2,
      ),
      Conversation(
        partnerId: 2,
        partnerName: "Jean Martin",
        partnerPhoto: "https://i.pravatar.cc/150?img=2",
        partnerRole: "user",
        lastMessage: "📸 Photo",
        lastMessageTime: DateTime.now().subtract(const Duration(minutes: 30)),
        unreadCount: 0,
      ),
      Conversation(
        partnerId: 3,
        partnerName: "Sophie Laurent",
        partnerPhoto: "https://i.pravatar.cc/150?img=3",
        partnerRole: "user",
        lastMessage: "🎵 Audio (0:45)",
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 1)),
        unreadCount: 1,
      ),
      Conversation(
        partnerId: 4,
        partnerName: "Pierre Rousseau",
        partnerPhoto: "https://i.pravatar.cc/150?img=4",
        partnerRole: "user",
        lastMessage: "D'accord, on se voit demain !",
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 2)),
        unreadCount: 0,
      ),
      Conversation(
        partnerId: 5,
        partnerName: "Emma Garcia",
        partnerPhoto: "https://i.pravatar.cc/150?img=5",
        partnerRole: "user",
        lastMessage: "🎥 Vidéo",
        lastMessageTime: DateTime.now().subtract(const Duration(hours: 3)),
        unreadCount: 3,
      ),
    ];

    setState(() {
      _conversations = staticConversations;
      _filteredConversations = staticConversations;
      _errorMessage = null;
    });
    
    print('⚠️ [CONVERSATIONS] Utilisation des données statiques fallback');
  }

  // 🔥 MÉTHODE DE FILTRAGE CORRIGÉE
  void _filterConversations() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredConversations = _conversations
          .where((conversation) =>
              conversation.partnerName.toLowerCase().contains(query) ||
              (conversation.lastMessage?.toLowerCase().contains(query) ?? false))
          .toList();
    });
  }

  // 🔥 NAVIGATION VERS CHAT CORRIGÉE
  void _openChat(Conversation conversation) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => chat.ChatScreen(
          partnerId: conversation.partnerId,
          partnerName: conversation.partnerName,
          partnerPhoto: conversation.partnerPhoto,
          isOnline: false, // Pas d'info online dans le modèle Conversation
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Column(
        children: [
          _buildSearchBar(),
          Expanded(
            child: _buildConversationsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Nouvelle conversation'),
              backgroundColor: primaryColor,
            ),
          );
        },
        backgroundColor: primaryColor,
        child: const Icon(Icons.message, color: Colors.white),
      ),
    );
  }

  // 🔥 APPBAR AVEC COULEURS COHÉRENTES
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: primaryColor,
      elevation: 0,
      title: const Text(
        'Messages',
        style: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {
            // Focus sur la barre de recherche
            FocusScope.of(context).requestFocus();
          },
        ),
        IconButton(
          icon: const Icon(Icons.more_vert, color: Colors.white),
          onPressed: () {
            _showOptionsMenu();
          },
        ),
      ],
    );
  }

  // 🔥 BARRE DE RECHERCHE AVEC COULEURS COHÉRENTES
  Widget _buildSearchBar() {
    return Container(
      color: primaryColor,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(25),
        ),
        child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            hintText: 'Rechercher dans les conversations...',
            prefixIcon: Icon(Icons.search, color: Colors.grey),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
        ),
      ),
    );
  }

  // 🔥 LISTE DES CONVERSATIONS CORRIGÉE
  Widget _buildConversationsList() {
    if (_isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: primaryColor),
            const SizedBox(height: 16),
            const Text('Chargement des conversations...'),
          ],
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadConversations,
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }

    if (_filteredConversations.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadConversations,
      color: primaryColor,
      child: ListView.builder(
        itemCount: _filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = _filteredConversations[index];
          return _ConversationTile(
            conversation: conversation,
            onTap: () => _openChat(conversation),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.message_outlined,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune conversation trouvée',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Commencez une nouvelle conversation',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 MENU OPTIONS AVEC COULEURS COHÉRENTES
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            _MenuOption(
              icon: Icons.group_add,
              title: 'Nouveau groupe',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Nouveau groupe');
              },
            ),
            _MenuOption(
              icon: Icons.settings,
              title: 'Paramètres',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Paramètres');
              },
            ),
            _MenuOption(
              icon: Icons.archive,
              title: 'Conversations archivées',
              onTap: () {
                Navigator.pop(context);
                _showSnackBar('Conversations archivées');
              },
            ),
            _MenuOption(
              icon: Icons.refresh,
              title: 'Actualiser',
              onTap: () {
                Navigator.pop(context);
                _loadConversations();
              },
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: primaryColor,
      ),
    );
  }
}

// 🔥 WIDGET CONVERSATION TILE CORRIGÉ
class _ConversationTile extends StatelessWidget {
  final Conversation conversation;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conversation,
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: Colors.grey[200]!,
              width: 0.5,
            ),
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[300],
              backgroundImage: conversation.partnerPhoto != null
                  ? NetworkImage(conversation.partnerPhoto!)
                  : null,
              child: conversation.partnerPhoto == null
                  ? Text(
                      conversation.partnerName[0].toUpperCase(),
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        conversation.partnerName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: conversation.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        _formatTimestamp(conversation.lastMessageTime),
                        style: TextStyle(
                          fontSize: 12,
                          color: conversation.unreadCount > 0
                              ? primaryColor
                              : Colors.grey[600],
                          fontWeight: conversation.unreadCount > 0
                              ? FontWeight.w600
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            _buildMessageTypeIcon(),
                            Expanded(
                              child: Text(
                                conversation.lastMessage ?? 'Aucun message',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: conversation.unreadCount > 0
                                      ? Colors.black87
                                      : Colors.grey[600],
                                  fontWeight: conversation.unreadCount > 0
                                      ? FontWeight.w500
                                      : FontWeight.normal,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (conversation.unreadCount > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: const BoxDecoration(
                            color: primaryColor,
                            shape: BoxShape.circle,
                          ),
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          child: Text(
                            conversation.unreadCount > 99
                                ? '99+'
                                : conversation.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageTypeIcon() {
    final lastMessage = conversation.lastMessage ?? '';
    
    if (lastMessage.contains('📸') || lastMessage.toLowerCase().contains('photo')) {
      return const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Icon(
          Icons.image,
          size: 16,
          color: Colors.grey,
        ),
      );
    } else if (lastMessage.contains('🎥') || lastMessage.toLowerCase().contains('vidéo')) {
      return const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Icon(
          Icons.videocam,
          size: 16,
          color: Colors.grey,
        ),
      );
    } else if (lastMessage.contains('🎤') || lastMessage.contains('🎵') || lastMessage.toLowerCase().contains('audio')) {
      return const Padding(
        padding: EdgeInsets.only(right: 4),
        child: Icon(
          Icons.mic,
          size: 16,
          color: Colors.grey,
        ),
      );
    } else {
      return const SizedBox.shrink();
    }
  }

  String _formatTimestamp(DateTime? timestamp) {
    if (timestamp == null) return '';
    
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Hier';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}j';
      } else {
        return '${timestamp.day}/${timestamp.month}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Maintenant';
    }
  }
}

// 🔥 WIDGET MENU OPTION AVEC COULEURS COHÉRENTES
class _MenuOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;

  const _MenuOption({
    required this.icon,
    required this.title,
    required this.onTap,
  });

  static const Color primaryColor = Color(0xFFFF6B35);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        icon,
        color: primaryColor,
      ),
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
      ),
      onTap: onTap,
    );
  }
}