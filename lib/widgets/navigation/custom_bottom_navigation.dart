// lib/widgets/navigation/custom_bottom_navigation.dart
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../utils/chat_navigation.dart';
import '../../pages/profile/profile_page.dart';
import '../../pages/cart/cart_page.dart';
import '../../pages/merchant/merchant_shop_page.dart';
import '../../pages/notifications/notification_page.dart';
import '../../services/cart_service.dart';

class CustomBottomNavigation extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String userType;

  const CustomBottomNavigation({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.userType,
  }) : super(key: key);

  @override
  State<CustomBottomNavigation> createState() => _CustomBottomNavigationState();
}

class _CustomBottomNavigationState extends State<CustomBottomNavigation> {
  final CartService _cartService = CartService();
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCartCount();
    
    // Écouter les changements du panier en temps réel
    _cartService.cartStream.listen((cart) {
      if (mounted) {
        setState(() {
          _cartItemCount = cart?.itemsCount ?? 0;
        });
      }
    });
  }

  Future<void> _loadCartCount() async {
    try {
      final count = await _cartService.getCartItemsCount();
      if (mounted) {
        setState(() {
          _cartItemCount = count;
        });
      }
    } catch (e) {
      print('❌ [BOTTOM_NAV] Erreur chargement compteur panier: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: (index) => _handleTap(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: _buildNavigationItems(),
      ),
    );
  }

  // 🔥 GESTION DU TAP AVEC NAVIGATION SPÉCIALE - MISE À JOUR
  void _handleTap(BuildContext context, int index) {
    print('🔥 [BOTTOM_NAV] Tap sur index: $index, userType: ${widget.userType}');
    
    // Index 1 = Messages
    if (index == 1) {
      print('🔥 [BOTTOM_NAV] Navigation vers Messages');
      ChatNavigation.navigateToConversations(context);
    } 
    // Index 2 = Panier
    else if (index == 2) {
      print('🔥 [BOTTOM_NAV] Navigation vers Panier');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CartPage(),
        ),
      );
    } 
    // Index 3 = Notifications (POUR TOUS)
    else if (index == 3) {
      print('🔥 [BOTTOM_NAV] Navigation vers Notifications');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const NotificationPage(),
        ),
      );
    }
    // Index 4 = Ma Boutique (SEULEMENT MERCHANTS) ou Profil (CLIENTS)
    else if (index == 4) {
      if (widget.userType == 'merchant') {
        print('🔥 [BOTTOM_NAV] Navigation vers Ma Boutique (merchant)');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MerchantShopPage(),
          ),
        );
      } else {
        print('🔥 [BOTTOM_NAV] Navigation vers Profil (client)');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ProfilePage(),
          ),
        );
      }
    }
    // Index 5 = Profil (SEULEMENT MERCHANTS)
    else if (index == 5 && widget.userType == 'merchant') {
      print('🔥 [BOTTOM_NAV] Navigation vers Profil (merchant)');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ProfilePage(),
        ),
      );
    } 
    else {
      // Pour les autres onglets, utiliser la fonction onTap normale
      widget.onTap(index);
    }
  }

  List<BottomNavigationBarItem> _buildNavigationItems() {
    List<BottomNavigationBarItem> items = [
      // Index 0: Accueil
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Accueil',
      ),
      // Index 1: Messages
      const BottomNavigationBarItem(
        icon: Icon(Icons.message),
        label: 'Messages',
      ),
      // Index 2: Panier avec badge
      BottomNavigationBarItem(
        icon: _buildCartIconWithBadge(),
        label: 'Panier',
      ),
      // Index 3: Notifications (POUR TOUS - merchants et clients)
      const BottomNavigationBarItem(
        icon: Icon(Icons.notifications_outlined),
        label: 'Notifications',
      ),
    ];

    // Index 4 et 5 : Différencier selon le type d'utilisateur
    if (widget.userType == 'merchant') {
      // MERCHANTS: Ma Boutique + Profil
      items.addAll([
        // Index 4: Ma Boutique (seulement merchants)
        const BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: 'Ma Boutique',
        ),
        // Index 5: Profil (merchants)
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ]);
    } else {
      // CLIENTS: Profil seulement
      items.add(
        // Index 4: Profil (clients)
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      );
    }

    return items;
  }

  // 🔥 ICÔNE PANIER AVEC BADGE DU NOMBRE D'ARTICLES
  Widget _buildCartIconWithBadge() {
    return Stack(
      children: [
        const Icon(Icons.shopping_cart),
        if (_cartItemCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _cartItemCount > 99 ? '99+' : _cartItemCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// 🔥 VERSION ALTERNATIVE AVEC BADGE DE NOTIFICATIONS
class CustomBottomNavigationWithBadge extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTap;
  final String userType;
  final int unreadMessagesCount;
  final int unreadNotificationsCount; // 🔥 AJOUTÉ

  const CustomBottomNavigationWithBadge({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    required this.userType,
    this.unreadMessagesCount = 0,
    this.unreadNotificationsCount = 0, // 🔥 AJOUTÉ
  }) : super(key: key);

  @override
  State<CustomBottomNavigationWithBadge> createState() => _CustomBottomNavigationWithBadgeState();
}

class _CustomBottomNavigationWithBadgeState extends State<CustomBottomNavigationWithBadge> {
  final CartService _cartService = CartService();
  int _cartItemCount = 0;

  @override
  void initState() {
    super.initState();
    _loadCartCount();
    
    // Écouter les changements du panier en temps réel
    _cartService.cartStream.listen((cart) {
      if (mounted) {
        setState(() {
          _cartItemCount = cart?.itemsCount ?? 0;
        });
      }
    });
  }

  Future<void> _loadCartCount() async {
    try {
      final count = await _cartService.getCartItemsCount();
      if (mounted) {
        setState(() {
          _cartItemCount = count;
        });
      }
    } catch (e) {
      print('❌ [BOTTOM_NAV_BADGE] Erreur chargement compteur panier: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: BottomNavigationBar(
        currentIndex: widget.currentIndex,
        onTap: (index) => _handleTap(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.primaryOrange,
        unselectedItemColor: Colors.grey[600],
        selectedFontSize: 12,
        unselectedFontSize: 12,
        items: _buildNavigationItemsWithBadge(),
      ),
    );
  }

  // 🔥 MÊME GESTION POUR LA VERSION AVEC BADGE - MISE À JOUR
  void _handleTap(BuildContext context, int index) {
    print('🔥 [BOTTOM_NAV_BADGE] Tap sur index: $index, userType: ${widget.userType}');
    
    if (index == 1) {
      print('🔥 [BOTTOM_NAV] Navigation vers Messages');
      ChatNavigation.navigateToConversations(context);
    } 
    else if (index == 2) {
      print('🔥 [BOTTOM_NAV] Navigation vers Panier');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const CartPage(),
        ),
      );
    } 
    // Index 3 = Notifications (POUR TOUS)
    else if (index == 3) {
      print('🔥 [BOTTOM_NAV] Navigation vers Notifications');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const NotificationPage(),
        ),
      );
    }
    // Index 4 = Ma Boutique (MERCHANTS) ou Profil (CLIENTS)
    else if (index == 4) {
      if (widget.userType == 'merchant') {
        print('🔥 [BOTTOM_NAV] Navigation vers Ma Boutique (merchant)');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MerchantShopPage(),
          ),
        );
      } else {
        print('🔥 [BOTTOM_NAV] Navigation vers Profil (client)');
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => const ProfilePage(),
          ),
        );
      }
    }
    // Index 5 = Profil (SEULEMENT MERCHANTS)
    else if (index == 5 && widget.userType == 'merchant') {
      print('🔥 [BOTTOM_NAV] Navigation vers Profil (merchant)');
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => const ProfilePage(),
        ),
      );
    } 
    else {
      widget.onTap(index);
    }
  }

  List<BottomNavigationBarItem> _buildNavigationItemsWithBadge() {
    List<BottomNavigationBarItem> items = [
      // Index 0: Accueil
      const BottomNavigationBarItem(
        icon: Icon(Icons.home),
        label: 'Accueil',
      ),
      // Index 1: Messages avec badge
      BottomNavigationBarItem(
        icon: _buildMessageIconWithBadge(),
        label: 'Messages',
      ),
      // Index 2: Panier avec badge
      BottomNavigationBarItem(
        icon: _buildCartIconWithBadge(),
        label: 'Panier',
      ),
      // Index 3: Notifications avec badge (POUR TOUS)
      BottomNavigationBarItem(
        icon: _buildNotificationIconWithBadge(),
        label: 'Notifications',
      ),
    ];

    // Index 4 et 5 : Différencier selon le type d'utilisateur
    if (widget.userType == 'merchant') {
      // MERCHANTS: Ma Boutique + Profil
      items.addAll([
        // Index 4: Ma Boutique (seulement merchants)
        const BottomNavigationBarItem(
          icon: Icon(Icons.store),
          label: 'Ma Boutique',
        ),
        // Index 5: Profil (merchants)
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      ]);
    } else {
      // CLIENTS: Profil seulement
      items.add(
        // Index 4: Profil (clients)
        const BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          label: 'Profil',
        ),
      );
    }

    return items;
  }

  Widget _buildMessageIconWithBadge() {
    return Stack(
      children: [
        const Icon(Icons.message),
        if (widget.unreadMessagesCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.red,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                widget.unreadMessagesCount > 99 ? '99+' : widget.unreadMessagesCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCartIconWithBadge() {
    return Stack(
      children: [
        const Icon(Icons.shopping_cart),
        if (_cartItemCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: AppColors.primaryOrange,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                _cartItemCount > 99 ? '99+' : _cartItemCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }

  // 🔥 NOUVELLE MÉTHODE: Badge pour les notifications
  Widget _buildNotificationIconWithBadge() {
    return Stack(
      children: [
        const Icon(Icons.notifications_outlined),
        if (widget.unreadNotificationsCount > 0)
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: Colors.blue,
                borderRadius: BorderRadius.circular(10),
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: Text(
                widget.unreadNotificationsCount > 99 ? '99+' : widget.unreadNotificationsCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}

// Page sous construction réutilisable (identique)
class UnderConstructionPage extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;

  const UnderConstructionPage({
    Key? key,
    this.title = 'Page en construction',
    this.description = 'Cette fonctionnalité sera bientôt disponible !',
    this.icon = Icons.construction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 64,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}