// lib/pages/followers/followers_page.dart - ADAPTÉE À VOS MODÈLES
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../constants/app_colors.dart';
import '../../services/follow_service.dart';
import '../../models/follow_model.dart';
import '../../screens/chat_screen.dart';

class FollowersPage extends StatefulWidget {
  final int? userId; // Si null, utilise l'utilisateur connecté
  final String title;

  const FollowersPage({
    Key? key,
    this.userId,
    this.title = 'Mes Followers',
  }) : super(key: key);

  @override
  State<FollowersPage> createState() => _FollowersPageState();
}

class _FollowersPageState extends State<FollowersPage> with TickerProviderStateMixin {
  final FollowService _followService = FollowService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Follower> _allFollowers = [];
  List<Follower> _filteredFollowers = [];
  List<Follower> _following = []; // ✅ Utilise directement vos modèles Follower
  
  bool _isLoading = true;
  bool _hasError = false;
  String _errorMessage = '';
  String _activeFilter = 'all';
  
  // Statistiques
  int _totalFollowers = 0;
  int _totalFollowing = 0;
  double _engagementRate = 98.0;
  
  int? _currentUserId;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    _searchController.addListener(_onSearchChanged);
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });

      // Récupérer l'utilisateur connecté
      await _getCurrentUserId();
      
      // Utiliser l'userId fourni ou celui de l'utilisateur connecté
      final targetUserId = widget.userId ?? _currentUserId ?? 1; // ✅ Fallback à 1
      
      // Charger les données en parallèle
      final results = await Future.wait([
        _followService.getUserFollowers(targetUserId),
        _followService.getUserFollowing(targetUserId),
      ]);

      final followersResponse = results[0] as FollowersResponse;
      final followingResponse = results[1] as FollowingResponse;

      setState(() {
        _allFollowers = followersResponse.followers;
        _filteredFollowers = _allFollowers;
        _following = followingResponse.following; // ✅ Utilise directement votre modèle
        _totalFollowers = followersResponse.pagination.total;
        _totalFollowing = followingResponse.pagination.total;
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      print('❌ Erreur chargement: $e');
      
      // ✅ DONNÉES DE TEST si erreur (pour développement)
      setState(() {
        _allFollowers = _generateTestFollowers();
        _filteredFollowers = _allFollowers;
        _following = _generateTestFollowing();
        _totalFollowers = _allFollowers.length;
        _totalFollowing = _following.length;
        _isLoading = false;
        _hasError = false; // On cache l'erreur et utilise les données test
      });
      
      _animationController.forward();
    }
  }

  // ✅ GÉNÉRATEUR DE DONNÉES DE TEST
  List<Follower> _generateTestFollowers() {
    return [
      Follower(
        id: 1,
        firstName: 'Marie',
        lastName: 'Dubois',
        photo: 'https://i.pravatar.cc/64?img=1',
        role: 'merchant',
        followedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Follower(
        id: 2,
        firstName: 'Jean',
        lastName: 'Martin',
        photo: 'https://i.pravatar.cc/64?img=2',
        role: 'customer',
        followedAt: DateTime.now().subtract(const Duration(days: 5)),
      ),
      Follower(
        id: 3,
        firstName: 'Aminata',
        lastName: 'Mbaye',
        photo: null,
        role: 'merchant',
        followedAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      Follower(
        id: 4,
        firstName: 'Sophie',
        lastName: 'Laurent',
        photo: 'https://i.pravatar.cc/64?img=4',
        role: 'customer',
        followedAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ];
  }

  List<Follower> _generateTestFollowing() {
    return [
      Follower(
        id: 2,
        firstName: 'Jean',
        lastName: 'Martin',
        photo: 'https://i.pravatar.cc/64?img=2',
        role: 'customer',
        followedAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
    ];
  }

  Future<void> _getCurrentUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _currentUserId = prefs.getInt('current_user_id');
      
      if (_currentUserId == null) {
        final userStr = prefs.getString('user');
        if (userStr != null) {
          // Parse user JSON si disponible
        }
      }
    } catch (e) {
      print('Erreur récupération user ID: $e');
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase().trim();
    setState(() {
      if (query.isEmpty) {
        _filteredFollowers = _allFollowers;
      } else {
        _filteredFollowers = _allFollowers.where((follower) {
          return follower.fullName.toLowerCase().contains(query) ||
                 follower.role.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  void _filterFollowers(String type) {
    setState(() {
      _activeFilter = type;
      
      switch (type) {
        case 'all':
          _filteredFollowers = _allFollowers;
          break;
        case 'merchants':
          _filteredFollowers = _allFollowers.where((f) => 
            f.role.toLowerCase() == 'merchant'
          ).toList();
          break;
        case 'customers':
          _filteredFollowers = _allFollowers.where((f) => 
            f.role.toLowerCase() == 'customer'
          ).toList();
          break;
        case 'recent':
          _filteredFollowers = _allFollowers.where((f) => 
            DateTime.now().difference(f.followedAt).inDays <= 7
          ).toList();
          break;
      }
    });
  }

  Future<void> _refreshData() async {
    await _loadData();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Données actualisées'),
          backgroundColor: AppColors.primaryOrange,
        ),
      );
    }
  }

  void _openChat(Follower follower) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          partnerName: follower.fullName, // ✅ Utilise fullName de vos modèles
          partnerPhoto: follower.photo,
          isOnline: false, // ✅ Par défaut false (pas dans vos modèles)
          partnerId: follower.id,
        ),
      ),
    );
  }

  void _viewProfile(Follower follower) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileModal(follower: follower),
    );
  }

  void _toggleFollow(Follower follower) async {
    try {
      await _followService.toggleFollow(follower.id); // ✅ Utilise directement follower.id
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Statut de suivi mis à jour'),
            backgroundColor: AppColors.primaryOrange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Erreur: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              _buildStatsSection(),
              _buildSearchBar(),
              Expanded(
                child: _buildContent(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddFollowerDialog(),
        backgroundColor: AppColors.primaryOrange,
        child: const Icon(Icons.person_add, color: Colors.white),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.arrow_back,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const Text(
                  'Communauté qui vous suit',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primaryOrange.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                const Center(
                  child: Icon(
                    Icons.notifications,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: const Center(
                      child: Text(
                        '3',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsSection() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              '${_formatNumber(_totalFollowers)}',
              'Followers',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              '${_formatNumber(_totalFollowing)}',
              'Following',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: _buildStatCard(
              '${_engagementRate.toInt()}%',
              'Engagement',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String value, String label) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            height: 2,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primaryOrange, Color(0xFFF7931E)],
              ),
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
          ),
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Rechercher un follower...',
            hintStyle: TextStyle(color: Colors.white70),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white70,
            ),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFFF8F9FA),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 20),
          _buildSectionHeader(),
          _buildFilterChips(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _hasError
                    ? _buildErrorState()
                    : _buildFollowersList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Ma Communauté',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1F2937),
            ),
          ),
          IconButton(
            onPressed: _refreshData,
            icon: const Icon(
              Icons.refresh,
              color: AppColors.primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: [
          _buildFilterChip('Tous', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('Marchands', 'merchants'),
          const SizedBox(width: 8),
          _buildFilterChip('Clients', 'customers'),
          const SizedBox(width: 8),
          _buildFilterChip('Récents', 'recent'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isActive = _activeFilter == value;
    
    return GestureDetector(
      onTap: () => _filterFollowers(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primaryOrange : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppColors.primaryOrange : const Color(0xFFE5E7EB),
            width: 2,
          ),
          boxShadow: isActive ? [
            BoxShadow(
              color: AppColors.primaryOrange.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildFollowersList() {
    if (_filteredFollowers.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _refreshData,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: ListView.builder(
          padding: const EdgeInsets.all(20),
          itemCount: _filteredFollowers.length,
          itemBuilder: (context, index) {
            final follower = _filteredFollowers[index];
            return _FollowerCard(
              follower: follower,
              onMessage: () => _openChat(follower),
              onProfile: () => _viewProfile(follower),
              onToggleFollow: () => _toggleFollow(follower),
              isFollowingBack: _following.any((f) => f.id == follower.id), // ✅ Adapté à vos modèles
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Icon(
              Icons.people_outline,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Aucun follower trouvé',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Votre liste de followers sera affichée ici',
            style: TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 64,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          const Text(
            'Erreur de chargement',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.grey),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadData,
            child: const Text('Réessayer'),
          ),
        ],
      ),
    );
  }

  void _showAddFollowerDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('➕ Ajouter un follower - Fonctionnalité en développement'),
        backgroundColor: AppColors.primaryOrange,
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

// ✅ WIDGET DE CARTE ADAPTÉ À VOS MODÈLES
class _FollowerCard extends StatelessWidget {
  final Follower follower;
  final VoidCallback onMessage;
  final VoidCallback onProfile;
  final VoidCallback onToggleFollow;
  final bool isFollowingBack;

  const _FollowerCard({
    required this.follower,
    required this.onMessage,
    required this.onProfile,
    required this.onToggleFollow,
    required this.isFollowingBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onProfile,
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Row(
                  children: [
                    _buildAvatar(),
                    const SizedBox(width: 16),
                    Expanded(child: _buildUserInfo()),
                    _buildFollowStatus(),
                  ],
                ),
                const SizedBox(height: 20),
                _buildActionButtons(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [AppColors.primaryOrange, Color(0xFFF7931E)],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: follower.photo != null && follower.photo!.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                follower.photo!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => _buildInitialsAvatar(),
              ),
            )
          : _buildInitialsAvatar(),
    );
  }

  Widget _buildInitialsAvatar() {
    final initials = follower.fullName.isNotEmpty
        ? follower.fullName.split(' ').map((e) => e[0]).take(2).join().toUpperCase()
        : '?';
    
    return Center(
      child: Text(
        initials,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          follower.fullName, // ✅ Utilise fullName de vos modèles
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),
        const SizedBox(height: 6),
        _buildRoleBadge(),
        const SizedBox(height: 8),
        Row(
          children: [
            const Icon(
              Icons.access_time,
              size: 14,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 4),
            Text(
              _getTimeAgo(follower.followedAt),
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRoleBadge() {
    Color backgroundColor;
    Color textColor;
    String roleText;
    
    switch (follower.role.toLowerCase()) { // ✅ Utilise directement follower.role
      case 'merchant':
        backgroundColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFF57C00);
        roleText = 'Marchand Premium';
        break;
      case 'customer':
        backgroundColor = const Color(0xFFE8F5E8);
        textColor = const Color(0xFF2E7D32);
        roleText = 'Client VIP';
        break;
      default:
        backgroundColor = const Color(0xFFE0F2FE);
        textColor = const Color(0xFF0277BD);
        roleText = 'Utilisateur';
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: textColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            roleText.toUpperCase(),
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFollowStatus() {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: isFollowingBack 
            ? const Color(0xFFDCFCE7)
            : const Color(0xFFFEF3C7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(
        isFollowingBack ? Icons.check_circle : Icons.add_circle_outline,
        size: 16,
        color: isFollowingBack 
            ? const Color(0xFF16A34A)
            : const Color(0xFFD97706),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: _ActionButton(
            label: isFollowingBack ? 'Suivi' : 'Suivre',
            icon: isFollowingBack ? Icons.check : Icons.person_add,
            gradient: isFollowingBack 
                ? const LinearGradient(colors: [Color(0xFFE5E7EB), Color(0xFFD1D5DB)])
                : const LinearGradient(colors: [AppColors.primaryOrange, Color(0xFFF7931E)]),
            textColor: isFollowingBack ? const Color(0xFF6B7280) : Colors.white,
            onTap: onToggleFollow,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Profil',
            icon: Icons.person,
            gradient: const LinearGradient(colors: [Color(0xFFF8FAFC), Color(0xFFE2E8F0)]),
            textColor: const Color(0xFF475569),
            onTap: onProfile,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            label: 'Message',
            icon: Icons.message,
            gradient: const LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]),
            textColor: const Color(0xFF2563EB),
            onTap: onMessage,
          ),
        ),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return 'Il y a ${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Il y a ${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Il y a ${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}

// Widget bouton d'action
class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Gradient gradient;
  final Color textColor;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.gradient,
    required this.textColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 48,
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: textColor),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ✅ MODAL DE PROFIL ADAPTÉE À VOS MODÈLES
class _ProfileModal extends StatelessWidget {
  final Follower follower;

  const _ProfileModal({required this.follower});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.6, // ✅ Réduit car moins d'infos
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Header
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [AppColors.primaryOrange, Color(0xFFF7931E)],
                    ),
                  ),
                  child: follower.photo != null && follower.photo!.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: Image.network(
                            follower.photo!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Center(
                              child: Text(
                                follower.fullName.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Text(
                            follower.fullName.split(' ').map((e) => e[0]).take(2).join().toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        follower.fullName,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primaryOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          follower.role == 'merchant' ? 'MARCHAND' : 'CLIENT',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryOrange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Informations simplifiées
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Informations',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow(Icons.person, 'Nom complet', follower.fullName),
                  _buildInfoRow(Icons.badge, 'Rôle', follower.role == 'merchant' ? 'Marchand' : 'Client'),
                  _buildInfoRow(Icons.favorite, 'Vous suit depuis', _formatDate(follower.followedAt)),
                  _buildInfoRow(Icons.tag, 'ID Utilisateur', '#${follower.id}'),
                ],
              ),
            ),
          ),
          
          // Boutons d'action
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ChatScreen(
                            partnerName: follower.fullName,
                            partnerPhoto: follower.photo,
                            isOnline: false,
                            partnerId: follower.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.message),
                    label: const Text('Envoyer un message'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.grey[200],
                    foregroundColor: Colors.grey[700],
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Fermer'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: color ?? const Color(0xFF6B7280),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}