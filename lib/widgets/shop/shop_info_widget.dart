// lib/widgets/shop/shop_info_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/shop_model.dart';
import '../../models/follow_model.dart';
import '../../services/follow_service.dart';
import '../../services/api_config.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../screens/chat_screen.dart';
import '../../utils/chat_navigation.dart';

class ShopInfoWidget extends StatefulWidget {
  final Shop shop;
  final AnimationController buttonController;
  final Animation<double> buttonScaleAnimation;
  final VoidCallback? onStartMessage;
  final VoidCallback? onFollowChanged;

  const ShopInfoWidget({
    Key? key,
    required this.shop,
    required this.buttonController,
    required this.buttonScaleAnimation,
    this.onStartMessage,
    this.onFollowChanged,
  }) : super(key: key);

  @override
  State<ShopInfoWidget> createState() => _ShopInfoWidgetState();
}

class _ShopInfoWidgetState extends State<ShopInfoWidget> {
  // 🔥 SERVICE DE FOLLOW
  final FollowService _followService = FollowService();
  
  // 🔥 VARIABLES D'ÉTAT
  bool _isFollowing = false;
  bool _isFollowActionInProgress = false;
  bool _isMessageActionInProgress = false;
  int _followerCount = 0;

  @override
  void initState() {
    super.initState();
    
    // 🔍 DEBUG: Afficher les informations essentielles
    print('🏪 [SHOP_INFO] Initialisation:');
    print('  - Shop: ${widget.shop.name} (ID: ${widget.shop.id})');
    print('  - Owner: ${widget.shop.owner?.fullName ?? "Inconnu"} (User ID: ${widget.shop.userId})');
    print('  - API URL: ${ApiConfig.baseUrl}/api/users/${widget.shop.userId}/toggle-follow');
    
    _initializeFollowState();
  }

  // 🔧 INITIALISATION DE L'ÉTAT DE SUIVI
  Future<void> _initializeFollowState() async {
    final ownerId = _getOwnerId();
    if (ownerId == null) {
      print('❌ [SHOP_INFO] Impossible d\'initialiser le suivi - ownerId null');
      return;
    }
    
    print('🔄 [SHOP_INFO] Initialisation du suivi pour owner ID: $ownerId');
    
    try {
      // Vérifier si on suit déjà cette boutique
      final isFollowingResponse = await _followService.checkIfFollowing(ownerId);
      
      // Récupérer le nombre d'abonnés (première page pour avoir le total)
      final followersResponse = await _followService.getUserFollowers(
        ownerId,
        page: 1,
        limit: 1,
      );
      
      if (mounted) {
        setState(() {
          _isFollowing = isFollowingResponse.isFollowing;
          _followerCount = followersResponse.pagination.total;
        });
        
        print('✅ [SHOP_INFO] État du suivi initialisé: following=$_isFollowing, followers=$_followerCount');
      }
    } catch (e) {
      print('❌ [SHOP_INFO] Erreur initialisation follow: $e');
      
      // Afficher plus de détails sur l'erreur
      if (e is FollowException) {
        print('❌ [SHOP_INFO] Code erreur: ${e.code}');
        print('❌ [SHOP_INFO] Message: ${e.message}');
      }
      
      // En cas d'erreur, on continue sans crash
      if (mounted) {
        setState(() {
          _isFollowing = false;
          _followerCount = 0;
        });
      }
    }
  }

  // 🔧 GESTION DU TOGGLE FOLLOW
  Future<void> _handleToggleFollow() async {
    final ownerId = _getOwnerId();
    if (_isFollowActionInProgress || ownerId == null) return;

    setState(() {
      _isFollowActionInProgress = true;
    });

    // Feedback haptique
    HapticFeedback.lightImpact();

    try {
      // Animation du bouton
      widget.buttonController.forward().then((_) {
        widget.buttonController.reverse();
      });

      // Appeler le service
      final response = await _followService.toggleFollow(ownerId);
      
      if (mounted) {
        setState(() {
          _isFollowing = response.isFollowed;
          _followerCount = response.followerCount;
          _isFollowActionInProgress = false;
        });

        // Afficher un message de succès
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isFollowing 
                  ? '✅ Vous suivez maintenant ${widget.shop.name}'
                  : '👋 Vous ne suivez plus ${widget.shop.name}',
            ),
            backgroundColor: _isFollowing ? Colors.green : Colors.grey[600],
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );

        // 🔥 NOTIFIER LE CHANGEMENT POUR RAFRAÎCHIR LES STATS
        widget.onFollowChanged?.call();
      }
    } catch (e) {
      print('❌ [SHOP_INFO] Erreur follow: $e');
      
      if (mounted) {
        setState(() {
          _isFollowActionInProgress = false;
        });

        String errorMessage = 'Erreur lors du suivi';
        if (e is FollowException) {
          if (e.code == 'NOT_AUTHENTICATED') {
            errorMessage = 'Connectez-vous pour suivre cette boutique';
          } else {
            errorMessage = e.message;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // 🔥 GESTION DU MESSAGE AVEC NAVIGATION CHAT
 // 🔥 REMPLACER LA MÉTHODE _handleStartMessage dans shop_info_widget.dart

Future<void> _handleStartMessage() async {
  print('🔥 [DEBUG] === DÉBUT _handleStartMessage ===');
  print('🔥 [DEBUG] Shop: ${widget.shop.name}');
  print('🔥 [DEBUG] _isMessageActionInProgress: $_isMessageActionInProgress');
  
  if (_isMessageActionInProgress) {
    print('❌ [DEBUG] Action déjà en cours, arrêt');
    return;
  }

  final ownerId = _getOwnerId();
  print('🔥 [DEBUG] Owner ID récupéré: $ownerId');
  
  if (ownerId == null) {
    print('❌ [DEBUG] Owner ID est null');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Impossible de contacter ce vendeur - ID manquant'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
    return;
  }

  setState(() {
    _isMessageActionInProgress = true;
  });

  print('🔥 [DEBUG] État mis à jour, _isMessageActionInProgress = true');

  // Feedback haptique
  HapticFeedback.lightImpact();

  try {
    // Animation du bouton
    widget.buttonController.forward().then((_) {
      widget.buttonController.reverse();
    });

    print('🔥 [DEBUG] Animation lancée');

    // 🔥 DONNÉES POUR LA NAVIGATION
    final userName = widget.shop.owner?.fullName ?? widget.shop.name;
    final userPhoto = widget.shop.owner?.photo;
    
    print('🔥 [DEBUG] Données navigation:');
    print('  - userId: $ownerId');
    print('  - userName: $userName');
    print('  - userPhoto: $userPhoto');

    // 🔥 TEST DE NAVIGATION DIRECTE
    print('🚀 [DEBUG] Tentative de navigation...');
    
    // Vérifier si ChatNavigation existe
    try {
      ChatNavigation.navigateToChat(
        context,
        userId: ownerId,
        userName: userName,
        userPhoto: userPhoto,
        isOnline: false,
      );
      print('✅ [DEBUG] Navigation ChatNavigation.navigateToChat appelée');
    } catch (e) {
      print('❌ [DEBUG] Erreur ChatNavigation: $e');
      
      // Fallback - Navigation manuelle
      print('🔄 [DEBUG] Tentative navigation manuelle...');
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatScreen(
            partnerId: ownerId,
            partnerName: userName,
            partnerPhoto: userPhoto,
            isOnline: false,
          ),
        ),
      );
      print('✅ [DEBUG] Navigation manuelle effectuée');
    }

    // Afficher un message de confirmation
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('💬 Chat ouvert avec $userName'),
          backgroundColor: AppColors.primaryOrange,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
      print('✅ [DEBUG] SnackBar affiché');
    }

  } catch (e) {
    print('❌ [DEBUG] Erreur générale: $e');
    print('❌ [DEBUG] Type d\'erreur: ${e.runtimeType}');
    print('❌ [DEBUG] Stack trace: ${StackTrace.current}');
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  } finally {
    print('🔥 [DEBUG] Finally block - remise à zéro de _isMessageActionInProgress');
    if (mounted) {
      setState(() {
        _isMessageActionInProgress = false;
      });
    }
    print('🔥 [DEBUG] === FIN _handleStartMessage ===');
  }
}

// 🔥 AJOUT D'IMPORT MANQUANT AU DÉBUT DU FICHIER
// Assurez-vous d'avoir cet import en haut du fichier :


// 🔥 MÉTHODE DE TEST SIMPLE
void _testNavigation() {
  print('🧪 [TEST] Test de navigation simple');
  final ownerId = _getOwnerId();
  
  if (ownerId != null) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text('Test Chat avec Owner $ownerId')),
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Test réussi !'),
                Text('Owner ID: $ownerId'),
                Text('Shop: ${widget.shop.name}'),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ChatScreen(
                          partnerId: ownerId,
                          partnerName: widget.shop.owner?.fullName ?? widget.shop.name,
                          partnerPhoto: widget.shop.owner?.photo,
                          isOnline: false,
                        ),
                      ),
                    );
                  },
                  child: Text('Aller vers Chat'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// 🔥 REMPLACER TEMPORAIREMENT _handleStartMessage PAR _testNavigation 
// Dans _buildActionButtons(), changez temporairement:
// onPressed: _handleStartMessage,
// par:
// onPressed: _testNavigation,

  // 🔥 MÉTHODE ALTERNATIVE : AFFICHER OPTIONS DE CONTACT
  void _showContactOptions() {
    final ownerId = _getOwnerId();
    
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
            Text(
              'Contacter ${widget.shop.name}',
              style: AppTextStyles.heading1,
            ),
            const SizedBox(height: 20),
            
            // Option Chat en direct
            _ContactOption(
              icon: Icons.chat,
              title: 'Chat en direct',
              subtitle: 'Conversation instantanée',
              color: AppColors.primaryOrange,
              onTap: () {
                Navigator.pop(context);
                if (ownerId != null) {
                  ChatNavigation.navigateToChat(
                    context,
                    userId: ownerId,
                    userName: widget.shop.owner?.fullName ?? widget.shop.name,
                    userPhoto: null, // 🔧 Correction : null pour l'instant
                    isOnline: false,
                  );
                }
              },
            ),
            
            const SizedBox(height: 12),
            
            // Option Email
            _ContactOption(
              icon: Icons.email,
              title: 'Envoyer un email',
              subtitle: _getOwnerEmail(),
              color: Colors.blue,
              onTap: () {
                Navigator.pop(context);
                _sendEmail();
              },
            ),
            
            const SizedBox(height: 12),
            
            // Option Voir toutes les conversations
            _ContactOption(
              icon: Icons.message_outlined,
              title: 'Toutes les conversations',
              subtitle: 'Voir votre messagerie',
              color: Colors.green,
              onTap: () {
                Navigator.pop(context);
                ChatNavigation.navigateToConversations(context);
              },
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // 🔧 ENVOYER UN EMAIL
  void _sendEmail() {
    // TODO: Intégrer avec url_launcher pour ouvrir l'app email
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Ouverture de l\'email vers ${_getOwnerEmail()}'),
        backgroundColor: Colors.blue,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // 🔧 MÉTHODE POUR OBTENIR L'ID DU PROPRIÉTAIRE
  int? _getOwnerId() {
    // 🔥 SOLUTION TROUVÉE : Utiliser shop.userId qui est l'ID du propriétaire
    final ownerId = widget.shop.userId;
    
    print('✅ [SHOP_INFO] Owner ID trouvé: $ownerId (depuis shop.userId)');
    print('📋 [SHOP_INFO] Shop: ${widget.shop.name}');
    print('👤 [SHOP_INFO] Owner: ${widget.shop.owner?.fullName ?? "Propriétaire inconnu"}');
    
    return ownerId;
  }

  // 🔧 MÉTHODE POUR OBTENIR LE NOM D'UTILISATEUR
  String _getShopUserName() {
    if (widget.shop.owner != null) {
      final fullName = widget.shop.owner!.fullName;
      if (fullName.isNotEmpty) {
        return fullName.toLowerCase().replaceAll(' ', '_');
      }
    }
    return 'boutique_${widget.shop.id}';
  }

  // 🔧 MÉTHODE POUR OBTENIR L'EMAIL DU PROPRIÉTAIRE
  String _getOwnerEmail() {
    // TODO: Ajouter le champ email dans votre modèle Owner
    // Pour l'instant, on simule avec un format basé sur le nom
    if (widget.shop.owner != null) {
      final username = _getShopUserName();
      return '$username@example.com'; // À remplacer par la vraie logique
    }
    return 'contact@${widget.shop.name.toLowerCase().replaceAll(' ', '')}.com';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 60, 16, 16),
      padding: const EdgeInsets.all(20.0),
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          widget.shop.name,
                          style: AppTextStyles.heading1.copyWith(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        if (widget.shop.verifiedBadge)
                          const Icon(
                            Icons.verified,
                            color: AppColors.primaryOrange,
                            size: 20,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '@${_getShopUserName()}',
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.gray600,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 🔥 AFFICHAGE DE L'EMAIL DU PROPRIÉTAIRE
                    Text(
                      _getOwnerEmail(),
                      style: AppTextStyles.subtitle.copyWith(
                        color: AppColors.gray500,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // 🔥 AFFICHAGE DU NOMBRE D'ABONNÉS
                    if (_followerCount > 0)
                      Text(
                        '$_followerCount abonné${_followerCount > 1 ? 's' : ''}',
                        style: AppTextStyles.subtitle.copyWith(
                          color: AppColors.gray600,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                  ],
                ),
              ),
              _buildActionButtons(),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            widget.shop.description ?? 'Bienvenue dans notre boutique !',
            style: AppTextStyles.subtitle.copyWith(fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        _buildActionButton(
          icon: _isFollowing ? Icons.person_remove_outlined : Icons.person_add_outlined,
          label: _isFollowing ? 'Suivi' : 'Suivre',
          isFollowing: _isFollowing,
          onPressed: _handleToggleFollow,
          isLoading: _isFollowActionInProgress,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: Icons.message_outlined,
          label: 'Message',
          onPressed: _handleStartMessage, // 🔥 NAVIGATION DIRECTE VERS LE CHAT
          isLoading: _isMessageActionInProgress,
          isMessageButton: true, // 🔥 IDENTIFIER LE BOUTON MESSAGE
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool isFollowing = false,
    bool isLoading = false,
    bool isMessageButton = false, // 🔥 NOUVEAU PARAMÈTRE
  }) {
    return ScaleTransition(
      scale: widget.buttonScaleAnimation,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing || isMessageButton 
              ? AppColors.primaryOrange 
              : AppColors.white,
          foregroundColor: isFollowing || isMessageButton 
              ? AppColors.white 
              : AppColors.primaryOrange,
          elevation: 0,
          side: BorderSide(
            color: AppColors.primaryOrange.withOpacity(0.3),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
        icon: isLoading 
            ? SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isFollowing || isMessageButton 
                      ? AppColors.white 
                      : AppColors.primaryOrange,
                ),
              )
            : Icon(icon, size: 16),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isFollowing || isMessageButton 
                ? AppColors.white 
                : AppColors.primaryOrange,
          ),
        ),
      ),
    );
  }

  BoxDecoration _getCardDecoration() {
    return BoxDecoration(
      color: AppColors.white,
      borderRadius: BorderRadius.circular(20.0),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.05),
          blurRadius: 10.0,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}

// 🔥 WIDGET POUR LES OPTIONS DE CONTACT
class _ContactOption extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ContactOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.subtitle.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.subtitle.copyWith(
                      color: AppColors.gray600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.grey[400],
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}