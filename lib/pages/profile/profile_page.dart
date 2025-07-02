// lib/pages/profile/profile_page.dart - VERSION COMPLÈTE AVEC DEBUG PROFILEDATA
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import 'edit_profile_page.dart';
import '../../services/api_config.dart';
import '../orders/orders_page.dart';
import '../merchant/merchant_stats_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({Key? key}) : super(key: key);

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final AuthService _authService = AuthService();
  User? _currentUser;
  ProfileData? _profileData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _debugApiConfig(); // Debug des URLs
    _loadUserProfile();
  }

  // 🔧 DEBUG : Afficher la configuration API
  void _debugApiConfig() {
    print('🔍 ===== DEBUG API CONFIG =====');
    print('Base URL: ${ApiConfig.baseUrl}');
    print('Login Endpoint: ${ApiConfig.loginEndpoint}');
    try {
      AuthService.printAllEndpoints();
    } catch (e) {
      print('⚠️ Erreur debug endpoints: $e');
    }
    print('🔍 ==============================');
  }

  // 🔧 MÉTHODE AMÉLIORÉE POUR CHARGER LE PROFIL
  Future<void> _loadUserProfile() async {
    try {
      print('🔄 === CHARGEMENT PROFIL AMÉLIORÉ ===');
      
      // 1. CHARGER L'UTILISATEUR LOCAL
      final user = await _authService.getUser();
      if (user == null) {
        print('❌ Aucun utilisateur en local');
        setState(() => _isLoading = false);
        return;
      }
      
      print('👤 Utilisateur local trouvé: ${user.fullName}');
      print('📧 Email: ${user.email}');
      print('🖼️ Avatar local: "${user.avatar}"');
      
      // 2. TESTER LA CONNEXION
      print('🌐 Test connexion serveur...');
      bool serverAvailable = false;
      try {
        serverAvailable = await _authService.testConnection();
        print('📡 Serveur: ${serverAvailable ? "✅ ACCESSIBLE" : "❌ INACCESSIBLE"}');
      } catch (e) {
        print('⚠️ Erreur test connexion: $e');
      }
      
      // 3. RÉCUPÉRER LES DONNÉES DEPUIS L'API
      ProfileData? profileData;
      if (serverAvailable) {
        try {
          print('🔄 Récupération profile depuis API...');
          profileData = await _authService.getUserProfile();
          
          if (profileData != null) {
            print('✅ ProfileData récupéré !');
            print('📸 Photo API: "${profileData.photo}"');
            print('👤 Nom API: ${profileData.firstName} ${profileData.lastName}');
            print('📱 Téléphone API: ${profileData.phoneNumber}');
            print('🏠 Adresse API: ${profileData.city}, ${profileData.country}');
          } else {
            print('⚠️ ProfileData est null après getUserProfile()');
          }
        } catch (e) {
          print('❌ Erreur récupération ProfileData: $e');
          print('❌ Type erreur: ${e.runtimeType}');
          print('❌ Stack trace: ${e.toString()}');
          
          // Afficher l'erreur dans l'interface si c'est une erreur d'authentification
          if (e.toString().contains('NOT_AUTHENTICATED') || 
              e.toString().contains('INVALID_TOKEN')) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Session expirée. Veuillez vous reconnecter.'),
                  backgroundColor: AppColors.error,
                  action: SnackBarAction(
                    label: 'Se reconnecter',
                    textColor: Colors.white,
                    onPressed: () {
                      Navigator.pushNamedAndRemoveUntil(
                        context, 
                        '/login', 
                        (route) => false,
                      );
                    },
                  ),
                ),
              );
            }
          }
        }
      }
      
      // 4. MISE À JOUR DE L'ÉTAT
      print('🔄 Mise à jour de l\'état...');
      print('📦 profileData avant setState: $profileData');
      
      setState(() {
        _currentUser = user;
        _profileData = profileData;
        _isLoading = false;
      });
      
      print('📦 _profileData après setState: $_profileData');
      print('📦 _profileData != null: ${_profileData != null}');
      
      print('🎯 === RÉSUMÉ FINAL ===');
      print('👤 User: ${user.fullName}');
      print('🖼️ Photo finale: "${profileData?.photo ?? user.avatar ?? "Aucune"}"');
      print('📡 Serveur accessible: $serverAvailable');
      print('🔄 ProfileData chargé: ${profileData != null}');
      print('🔄 _profileData (state): ${_profileData != null}');
      print('========================');
      
      // 5. AFFICHER MESSAGE SI HORS LIGNE
      if (!serverAvailable && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mode hors ligne - Données locales utilisées'),
            backgroundColor: Colors.amber,
            duration: Duration(seconds: 3),
          ),
        );
      }
      
    } catch (e) {
      print('❌ Erreur générale chargement profil: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  // 🔧 NOUVELLE MÉTHODE : Forcer le rechargement depuis l'API
  Future<void> _forceRefreshFromApi() async {
    print('🔄 === FORCE REFRESH API ===');
    
    setState(() => _isLoading = true);
    
    try {
      // Vider le cache et recharger
      final profileData = await _authService.getUserProfile();
      
      if (profileData != null) {
        print('✅ Données forcées depuis API');
        print('📸 Nouvelle photo: "${profileData.photo}"');
        
        setState(() {
          _profileData = profileData;
          _isLoading = false;
        });
        
        print('📦 _profileData après force refresh: $_profileData');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Profil mis à jour depuis le serveur'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      } else {
        print('❌ Force refresh: ProfileData est null');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('❌ Erreur force refresh: $e');
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur refresh: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  // 🔧 NOUVELLE MÉTHODE : Debug du parsing ProfileData
  Future<void> _debugProfileParsing() async {
    print('🧪 === DEBUG PROFILE PARSING COMPLET ===');
    
    try {
      final token = await _authService.getToken();
      if (token == null) {
        print('❌ Pas de token');
        return;
      }
      
      // Appel API direct avec debug complet
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/api/auth/profile'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );
      
      print('📊 Status: ${response.statusCode}');
      print('📄 Raw Response: ${response.body}');
      
      if (response.statusCode == 200) {
        // Parser le JSON manuellement pour voir la structure
        final Map<String, dynamic> data = jsonDecode(response.body);
        print('🔧 Data keys: ${data.keys}');
        print('🔧 Full data: $data');
        
        if (data['user'] != null) {
          final userData = data['user'];
          print('👤 User data keys: ${userData.keys}');
          print('👤 Full user data: $userData');
          
          // Vérifier spécifiquement la photo
          final photoField = userData['photo'];
          print('📸 Photo field type: ${photoField.runtimeType}');
          print('📸 Photo field value: "$photoField"');
          print('📸 Photo is null: ${photoField == null}');
          print('📸 Photo is empty: ${photoField?.toString().isEmpty}');
          
          // Essayer de créer ProfileData
          print('🔄 Tentative création ProfileData...');
          try {
            final profileData = ProfileData.fromJson(data);
            print('✅ ProfileData créé avec succès !');
            print('📸 ProfileData.photo: "${profileData.photo}"');
            print('📸 Toutes les propriétés ProfileData:');
            print('   - firstName: "${profileData.firstName}"');
            print('   - lastName: "${profileData.lastName}"');
            print('   - email: "${profileData.email}"');
            print('   - phoneNumber: "${profileData.phoneNumber}"');
            print('   - photo: "${profileData.photo}"');
            
            // Mettre à jour manuellement _profileData pour test
            print('🔄 Mise à jour manuelle _profileData pour test...');
            setState(() {
              _profileData = profileData;
            });
            print('✅ _profileData mis à jour manuellement: $_profileData');
            
            // Test avec ApiConfig.getImageUrl()
            if (profileData.photo != null && profileData.photo!.isNotEmpty) {
              String finalUrl = ApiConfig.getImageUrl(profileData.photo!);
              print('🌐 URL finale après ApiConfig: "$finalUrl"');
              
              // Test de l'URL de l'image
              try {
                final imageResponse = await http.get(Uri.parse(finalUrl));
                print('📸 Test image status: ${imageResponse.statusCode}');
                print('📸 Test image content-type: ${imageResponse.headers['content-type']}');
              } catch (imageError) {
                print('❌ Erreur test image: $imageError');
              }
            }
            
            // Afficher message de succès
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('✅ ProfileData créé et mis à jour !'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
            
          } catch (profileError) {
            print('❌ Erreur création ProfileData: $profileError');
            print('❌ Type erreur: ${profileError.runtimeType}');
            print('❌ Stack trace: $profileError');
            
            // Afficher l'erreur dans l'interface
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('❌ Erreur ProfileData: $profileError'),
                  backgroundColor: AppColors.error,
                  duration: Duration(seconds: 5),
                ),
              );
            }
          }
        }
      }
      
    } catch (e) {
      print('❌ Erreur debug parsing: $e');
    }
    
    print('🧪 === FIN DEBUG PARSING ===');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.gray50,
        body: Center(
          child: CircularProgressIndicator(
            color: AppColors.primaryOrange,
          ),
        ),
      );
    }

    if (_currentUser == null) {
      return _buildErrorState();
    }

    return Scaffold(
      backgroundColor: AppColors.gray50,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildProfileInfo(),
            const SizedBox(height: 20),
            _buildActionButtons(),
            const SizedBox(height: 20),
            _buildMenuOptions(),
            
            // 🧪 BOUTONS DE TEST (mode debug uniquement)
            if (kDebugMode) ...[
              const SizedBox(height: 20),
              _buildTestButtons(),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  // 🔧 APP BAR AVEC BOUTONS DE DEBUG
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Row(
        children: [
          Text(
            'Mon Profil',
            style: AppTextStyles.heading1.copyWith(fontSize: 18),
          ),
          // Indicateur hors ligne
          if (_profileData == null && _currentUser != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.offline_bolt, size: 12, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    'Hors ligne',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.amber,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
      backgroundColor: AppColors.white,
      elevation: 0,
      centerTitle: false,
      actions: [
        // 🔧 BOUTON DE REFRESH FORCÉ
        IconButton(
          onPressed: _forceRefreshFromApi,
          icon: const Icon(Icons.refresh, color: AppColors.info),
          tooltip: 'Recharger depuis le serveur',
        ),
        
        // 🔧 BOUTON DE DEBUG (mode développement)
        if (kDebugMode) ...[
          IconButton(
            onPressed: _showDebugDialog,
            icon: const Icon(Icons.bug_report, color: Colors.purple),
            tooltip: 'Debug info',
          ),
        ],
        
        // Bouton d'édition
        IconButton(
          onPressed: () => _navigateToEditProfile(),
          icon: const Icon(Icons.edit, color: AppColors.primaryOrange),
          tooltip: 'Modifier le profil',
        ),
      ],
    );
  }

  // 🎯 HEADER AVEC PHOTO ET INFOS PRINCIPALES
  Widget _buildProfileHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          // Photo de profil
          Stack(
            children: [
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primaryOrange.withOpacity(0.1),
                      AppColors.primaryOrange.withOpacity(0.3),
                    ],
                  ),
                  border: Border.all(
                    color: AppColors.primaryOrange.withOpacity(0.3),
                    width: 3,
                  ),
                ),
                child: ClipOval(
                  child: _buildProfileImage(),
                ),
              ),
              // Badge du rôle
              Positioned(
                bottom: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _currentUser!.isMerchant 
                      ? AppColors.success 
                      : AppColors.primaryOrange,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.white, width: 2),
                  ),
                  child: Icon(
                    _currentUser!.isMerchant 
                      ? Icons.store 
                      : Icons.person,
                    color: AppColors.white,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Nom complet
          Text(
            _currentUser!.fullName.isNotEmpty 
              ? _currentUser!.fullName 
              : 'Nom non renseigné',
            style: AppTextStyles.heading1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          
          // Rôle avec badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _getRoleColor().withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _getRoleColor().withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _getRoleIcon(),
                  size: 16,
                  color: _getRoleColor(),
                ),
                const SizedBox(width: 6),
                Text(
                  _getRoleText(),
                  style: AppTextStyles.caption.copyWith(
                    color: _getRoleColor(),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          
          // Email
          Text(
            _currentUser!.email ?? 'Email non renseigné',
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // 🔥 WIDGET AVEC DEBUG PROFILEDATA COMPLET
  Widget _buildProfileImage() {
    print('🎯 === DEBUG PROFILEDATA COMPLET ===');
    
    // Debug de l'état complet
    print('🔧 _profileData is null: ${_profileData == null}');
    print('🔧 _profileData object: $_profileData');
    
    if (_profileData != null) {
      print('✅ ProfileData existe !');
      print('📸 _profileData.photo: "${_profileData!.photo}"');
      print('👤 _profileData.firstName: "${_profileData!.firstName}"');
      print('👤 _profileData.lastName: "${_profileData!.lastName}"');
      print('📧 _profileData.email: "${_profileData!.email}"');
      
      // Forcer l'utilisation de ProfileData.photo si elle existe
      if (_profileData!.photo != null && _profileData!.photo!.isNotEmpty) {
        print('🔥 FORCING ProfileData photo: "${_profileData!.photo}"');
        String directUrl = _profileData!.photo!;
        
        return ClipOval(
          child: Image.network(
            directUrl, // Utilisation DIRECTE sans ApiConfig
            width: 120,
            height: 120,
            fit: BoxFit.cover,
            loadingBuilder: (context, child, progress) {
              if (progress == null) {
                print('✅ DIRECT Photo chargée avec succès !');
                return child;
              }
              print('⏳ DIRECT Chargement en cours...');
              return Center(
                child: CircularProgressIndicator(
                  color: AppColors.primaryOrange,
                  strokeWidth: 2,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              print('❌ DIRECT ERREUR:');
              print('   URL: $directUrl');
              print('   Erreur: $error');
              print('   StackTrace: $stackTrace');
              return _buildDefaultAvatar();
            },
          ),
        );
      } else {
        print('⚠️ ProfileData.photo is null or empty');
      }
    } else {
      print('❌ ProfileData est null !');
    }
    
    // Fallback vers avatar local
    String? avatarUrl = _currentUser?.avatar;
    print('🔧 Fallback avatar local: "$avatarUrl"');
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      print('🔄 Utilisation avatar local');
      String finalUrl = ApiConfig.getImageUrl(avatarUrl);
      
      return ClipOval(
        child: Image.network(
          finalUrl,
          width: 120,
          height: 120,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) {
              print('✅ Avatar local chargé !');
              return child;
            }
            return Center(
              child: CircularProgressIndicator(
                color: AppColors.primaryOrange,
                strokeWidth: 2,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            print('❌ Erreur avatar local: $error');
            return _buildDefaultAvatar();
          },
        ),
      );
    }
    
    print('⚠️ Fallback vers avatar par défaut');
    return _buildDefaultAvatar();
  }

  // 🔥 AVATAR PAR DÉFAUT DYNAMIQUE (avec vraies initiales de l'utilisateur)
  Widget _buildDefaultAvatar() {
    print('👤 === GÉNÉRATION AVATAR PAR DÉFAUT ===');
    
    // Récupérer le nom depuis ProfileData (priorité) ou User (fallback)
    String? firstName = _profileData?.firstName ?? _currentUser?.firstName;
    String? lastName = _profileData?.lastName ?? _currentUser?.lastName;
    String? email = _currentUser?.email;
    
    print('🔧 Prénom: "$firstName"');
    print('🔧 Nom: "$lastName"');
    print('🔧 Email: "$email"');
    
    // Générer les initiales dynamiquement
    String initials = _generateInitials(firstName, lastName, email);
    print('🎯 Initiales générées: "$initials"');
    
    // Couleur d'avatar basée sur le nom (pour cohérence)
    Color avatarColor = _generateAvatarColor(firstName, lastName);
    print('🎨 Couleur avatar: $avatarColor');
    
    return Container(
      width: 120,
      height: 120,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            avatarColor,
            avatarColor.withOpacity(0.8),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: avatarColor.withOpacity(0.3),
            blurRadius: 10,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: 38,
            fontWeight: FontWeight.bold,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }

  // 🔥 MÉTHODE POUR GÉNÉRER LES INITIALES DYNAMIQUEMENT
  String _generateInitials(String? firstName, String? lastName, String? email) {
    String initials = '';
    
    // Première initiale du prénom
    if (firstName?.isNotEmpty == true) {
      initials += firstName![0].toUpperCase();
    }
    
    // Deuxième initiale du nom (si disponible)
    if (lastName?.isNotEmpty == true && initials.length < 2) {
      initials += lastName![0].toUpperCase();
    }
    
    // Fallback avec l'email si pas de nom complet
    if (initials.isEmpty && email?.isNotEmpty == true) {
      initials = email![0].toUpperCase();
      
      // Essayer de prendre une deuxième lettre de l'email
      if (email.length > 1) {
        String emailPart = email.split('@')[0]; // Partie avant @
        if (emailPart.length > 1) {
          initials += emailPart[1].toUpperCase();
        }
      }
    }
    
    // Fallback absolu
    if (initials.isEmpty) {
      initials = 'U'; // User
    }
    
    return initials;
  }

  // 🔥 MÉTHODE POUR GÉNÉRER UNE COULEUR BASÉE SUR LE NOM
  Color _generateAvatarColor(String? firstName, String? lastName) {
    // Liste de couleurs agréables pour les avatars
    final List<Color> avatarColors = [
      AppColors.primaryOrange,
      AppColors.success,
      AppColors.info,
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF673AB7), // Deep Purple
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF2196F3), // Blue
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF009688), // Teal
      const Color(0xFF4CAF50), // Green
      const Color(0xFF8BC34A), // Light Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF795548), // Brown
      const Color(0xFF607D8B), // Blue Grey
    ];
    
    // Générer un index basé sur le nom pour la cohérence
    String nameForHash = '${firstName ?? ''}${lastName ?? ''}'.toLowerCase();
    
    if (nameForHash.isEmpty) {
      return AppColors.primaryOrange; // Couleur par défaut
    }
    
    // Simple hash pour générer un index cohérent
    int hash = 0;
    for (int i = 0; i < nameForHash.length; i++) {
      hash = nameForHash.codeUnitAt(i) + ((hash << 5) - hash);
    }
    
    int colorIndex = hash.abs() % avatarColors.length;
    return avatarColors[colorIndex];
  }

  // 🧪 TEST COMPLET DE L'API POUR LES PHOTOS
  Future<void> _testApiPhotoFlow() async {
    print('🧪 === TEST COMPLET API PHOTO ===');
    
    try {
      // 1. Test de connexion de base
      print('🔄 1. Test connexion...');
      final token = await _authService.getToken();
      print('🔑 Token présent: ${token != null}');
      
      if (token == null) {
        print('❌ Pas de token - utilisateur non connecté');
        return;
      }
      
      // 2. Test endpoint /api/test
      print('🔄 2. Test endpoint de base...');
      final connectionOk = await _authService.testConnection();
      print('📡 Connexion: ${connectionOk ? "✅" : "❌"}');
      
      // 3. Test récupération profil avec debug détaillé
      print('🔄 3. Test getUserProfile avec debug...');
      
      try {
        final response = await http.get(
          Uri.parse('${ApiConfig.baseUrl}/api/auth/profile'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
            'Content-Type': 'application/json',
          },
        );
        
        print('📊 Status Code: ${response.statusCode}');
        print('📄 Response Headers: ${response.headers}');
        print('📄 Response Body: ${response.body}');
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          print('✅ JSON décodé avec succès');
          print('🔧 Structure response: ${data.keys}');
          
          if (data['user'] != null) {
            final userData = data['user'];
            print('👤 User data trouvé');
            print('📸 Photo field: "${userData['photo']}"');
            print('📧 Email: "${userData['email']}"');
            print('👤 Nom: "${userData['firstName']} ${userData['lastName']}"');
            
            // Vérifier spécifiquement la photo
            if (userData['photo'] != null && userData['photo'].toString().isNotEmpty) {
              String photoUrl = userData['photo'].toString();
              print('✅ Photo URL trouvée: "$photoUrl"');
              
              // Tester l'URL de la photo
              print('🔄 Test de l\'URL photo...');
              String finalUrl = ApiConfig.getImageUrl(photoUrl);
              print('🌐 URL finale: "$finalUrl"');
              
              // Test de chargement de l'image
              try {
                final imageResponse = await http.get(Uri.parse(finalUrl));
                print('📸 Image response: ${imageResponse.statusCode}');
                print('📏 Image size: ${imageResponse.contentLength} bytes');
                print('📄 Image type: ${imageResponse.headers['content-type']}');
                
                if (imageResponse.statusCode == 200) {
                  print('✅ IMAGE ACCESSIBLE !');
                } else {
                  print('❌ Image non accessible: ${imageResponse.statusCode}');
                }
              } catch (imageError) {
                print('❌ Erreur test image: $imageError');
              }
            } else {
              print('⚠️ Pas de photo dans les données utilisateur');
            }
          } else {
            print('❌ Pas de données user dans la response');
          }
        } else {
          print('❌ Erreur HTTP: ${response.statusCode}');
          print('📄 Error body: ${response.body}');
        }
      } catch (e) {
        print('❌ Erreur test profile: $e');
      }
      
      print('🧪 === FIN TEST API PHOTO ===');
      
    } catch (e) {
      print('❌ Erreur générale test API: $e');
    }
  }

  // 🧪 MÉTHODE POUR TESTER UNE URL D'IMAGE SPÉCIFIQUE
  Future<bool> _testImageUrl(String imageUrl) async {
    try {
      print('🔄 Test image: $imageUrl');
      
      final response = await http.get(
        Uri.parse(imageUrl),
        headers: {
          'User-Agent': 'Flutter App',
        },
      ).timeout(Duration(seconds: 10));
      
      print('📊 Image status: ${response.statusCode}');
      print('📏 Image size: ${response.contentLength} bytes');
      print('📄 Content-Type: ${response.headers['content-type']}');
      
      return response.statusCode == 200;
    } catch (e) {
      print('❌ Erreur test image: $e');
      return false;
    }
  }

  // 🧪 WIDGET DE TEST AVEC BOUTONS AMÉLIORÉS
  Widget _buildTestButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Text(
            '🧪 Tests de développement',
            style: AppTextStyles.heading1.copyWith(fontSize: 16),
          ),
          SizedBox(height: 12),
          
          // Première ligne de boutons
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _testApiPhotoFlow,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.api),
                  label: Text('Test API'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _forceRefreshFromApi,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.refresh),
                  label: Text('Refresh'),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Deuxième ligne de boutons  
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _debugProfileParsing,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.code),
                  label: Text('Debug Parse'),
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () async {
                    // Test URL photo spécifique
                    String? photoUrl = _profileData?.photo ?? _currentUser?.avatar;
                    if (photoUrl != null && photoUrl.isNotEmpty) {
                      String finalUrl = ApiConfig.getImageUrl(photoUrl);
                      bool works = await _testImageUrl(finalUrl);
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Image URL: ${works ? "✅ Fonctionne" : "❌ Erreur"}'),
                          backgroundColor: works ? Colors.green : Colors.red,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('❌ Pas d\'URL photo à tester'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.purple,
                    foregroundColor: Colors.white,
                  ),
                  icon: Icon(Icons.image),
                  label: Text('Test URL'),
                ),
              ),
            ],
          ),
          
          SizedBox(height: 8),
          
          // Bouton pour forcer rebuild du widget photo
          ElevatedButton.icon(
            onPressed: () {
              print('🔄 Force rebuild widget photo');
              setState(() {
                // Force un rebuild pour tester
              });
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Widget photo rebuild forcé'),
                  backgroundColor: AppColors.info,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            icon: Icon(Icons.refresh),
            label: Text('Force Rebuild Photo'),
          ),
        ],
      ),
    );
  }

  // 🔧 NOUVELLE MÉTHODE : Dialog de debug CORRIGÉ
  void _showDebugDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('🔧 Debug Info'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('📱 **Configuration API:**', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Base URL: ${ApiConfig.baseUrl}'),
              Text('Profile endpoint: ${AuthService.profileEndpoint}'),
              Text('Update endpoint: ${AuthService.updateProfileEndpoint}'),
              SizedBox(height: 10),
              
              Text('👤 **Utilisateur local:**', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Nom: ${_currentUser?.fullName ?? "N/A"}'),
              Text('Email: ${_currentUser?.email ?? "N/A"}'),
              Text('Avatar: ${_currentUser?.avatar ?? "N/A"}'),
              SizedBox(height: 10),
              
              Text('🌐 **ProfileData API:**', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('Chargé: ${_profileData != null ? "✅" : "❌"}'),
              Text('Photo: ${_profileData?.photo ?? "N/A"}'),
              Text('Nom: ${_profileData?.firstName ?? "N/A"} ${_profileData?.lastName ?? "N/A"}'),
              SizedBox(height: 10),
              
              Text('🔧 **Actions:**', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Test de toutes les URLs
              try {
                print('🧪 === TEST TOUTES LES URLs ===');
                
                // Test endpoint de base
                print('🔄 Test /api/test...');
                final testResult = await _authService.testConnection();
                print('📊 Test connection: $testResult');
                
                // Test récupération profil
                print('🔄 Test getUserProfile...');
                final profile = await _authService.getUserProfile();
                print('📊 Profile récupéré: ${profile != null}');
                if (profile != null) {
                  print('📸 Photo dans profile: "${profile.photo}"');
                }
                
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Tests terminés - Voir console'),
                    backgroundColor: AppColors.info,
                  ),
                );
              } catch (e) {
                print('❌ Erreur tests: $e');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Erreur tests: $e'),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            },
            child: Text('🧪 Tester APIs'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _forceRefreshFromApi();
            },
            child: Text('🔄 Force Refresh'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Fermer'),
          ),
        ],
      ),
    );
  }

  // 🎯 INFORMATIONS DÉTAILLÉES
  Widget _buildProfileInfo() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Informations personnelles',
            style: AppTextStyles.heading1.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 16),
          
          _buildInfoRow(Icons.person_outline, 'Prénom', _currentUser!.firstName ?? 'Non renseigné'),
          _buildInfoRow(Icons.person_outline, 'Nom', _currentUser!.lastName ?? 'Non renseigné'),
          _buildInfoRow(Icons.email_outlined, 'Email', _currentUser!.email ?? 'Non renseigné'),
          _buildInfoRow(Icons.phone_outlined, 'Téléphone', _formatPhoneNumber()),
          _buildInfoRow(Icons.location_on_outlined, 'Adresse', _formatAddress()),
          _buildInfoRow(Icons.work_outline, 'Rôle', _getRoleText()),
          _buildInfoRow(Icons.image_outlined, 'Photo', _getPhotoStatus()),
            
          if (_currentUser!.createdAt != null)
            _buildInfoRow(Icons.calendar_today_outlined, 'Membre depuis', _formatDate(_currentUser!.createdAt!)),
        ],
      ),
    );
  }

  // 🎯 BOUTONS D'ACTION
  Widget _buildActionButtons() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          if (_currentUser!.isMerchant) ...[
            _buildActionButton(
              icon: Icons.store,
              title: 'Gérer votre boutique',
              subtitle: 'Produits, commandes, statistiques',
              color: AppColors.success,
              onTap: () => _navigateToStoreManagement(),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.analytics,
              title: 'Statistiques de vente',
              subtitle: 'Voir vos performances',
              color: AppColors.info,
              onTap: () => _navigateToStatistics(),
            ),
          ] else ...[
            _buildActionButton(
              icon: Icons.favorite_outline,
              title: 'Mes favoris',
              subtitle: 'Produits que vous aimez',
              color: AppColors.error,
              onTap: () => _navigateToFavorites(),
            ),
            const SizedBox(height: 12),
            _buildActionButton(
              icon: Icons.shopping_bag_outlined,
              title: 'Mes commandes',
              subtitle: 'Historique des achats',
              color: AppColors.primaryOrange,
              onTap: () => _navigateToOrders(),
            ),
          ],
        ],
      ),
    );
  }

  // 🎯 OPTIONS DE MENU
  Widget _buildMenuOptions() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildMenuOption(Icons.settings_outlined, 'Paramètres', () => _navigateToSettings()),
          _buildMenuOption(Icons.help_outline, 'Aide & Support', () => _navigateToHelp()),
          _buildMenuOption(Icons.privacy_tip_outlined, 'Confidentialité', () => _navigateToPrivacy()),
          _buildMenuOption(Icons.info_outline, 'À propos', () => _navigateToAbout()),
          const Divider(height: 32, color: AppColors.gray200),
          _buildMenuOption(
            Icons.logout, 
            'Déconnexion', 
            () => _showLogoutDialog(),
            color: AppColors.error,
          ),
        ],
      ),
    );
  }

  // 🎯 WIDGETS HELPERS
  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.gray600),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: AppTextStyles.subtitle.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: AppTextStyles.subtitle.copyWith(
                color: AppColors.gray800,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.buttonTextSecondary.copyWith(
                      color: AppColors.gray800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: AppTextStyles.caption,
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray400),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuOption(IconData icon, String title, VoidCallback onTap, {Color? color}) {
    return ListTile(
      leading: Icon(icon, color: color ?? AppColors.gray600),
      title: Text(
        title,
        style: AppTextStyles.buttonTextSecondary.copyWith(
          color: color ?? AppColors.gray800,
        ),
      ),
      trailing: Icon(Icons.arrow_forward_ios, size: 16, color: AppColors.gray400),
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildErrorState() {
    return Scaffold(
      backgroundColor: AppColors.gray50,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_outlined, size: 64, color: AppColors.gray400),
              const SizedBox(height: 16),
              Text(
                'Problème de connexion',
                style: AppTextStyles.heading1.copyWith(
                  color: AppColors.gray800,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Impossible de charger votre profil.\nVérifiez votre connexion internet.',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.gray600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              
              // Bouton Réessayer
              ElevatedButton.icon(
                onPressed: _loadUserProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryOrange,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                icon: const Icon(Icons.refresh),
                label: Text('Réessayer', style: AppTextStyles.buttonText),
              ),
              
              const SizedBox(height: 16),
              
              // Bouton Mode hors ligne
              TextButton.icon(
                onPressed: () async {
                  // Tenter de charger seulement les données locales
                  final user = await _authService.getUser();
                  if (user != null) {
                    setState(() {
                      _currentUser = user;
                      _profileData = null; // Pas de données serveur
                      _isLoading = false;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Mode hors ligne activé'),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.gray600,
                ),
                icon: const Icon(Icons.offline_bolt_outlined),
                label: Text(
                  'Continuer hors ligne',
                  style: AppTextStyles.buttonTextSecondary.copyWith(
                    color: AppColors.gray600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🎯 HELPER METHODS
  Color _getRoleColor() {
    return _currentUser!.isMerchant ? AppColors.success : AppColors.primaryOrange;
  }

  IconData _getRoleIcon() {
    return _currentUser!.isMerchant ? Icons.store : Icons.person;
  }

  String _getRoleText() {
    return _currentUser!.isMerchant ? 'COMMERÇANT' : 'CLIENT';
  }

  String _formatPhoneNumber() {
    String? phone = _profileData?.phoneNumber ?? _currentUser?.phone;
    
    if (phone == null || phone.isEmpty) {
      return 'Non renseigné';
    }
    
    if (phone.length == 9) {
      return '${phone.substring(0, 3)} ${phone.substring(3, 5)} ${phone.substring(5, 7)} ${phone.substring(7, 9)}';
    }
    
    return phone;
  }
  
  String _formatAddress() {
    String? country = _profileData?.country ?? 'Non renseigné';
    String? city = _profileData?.city;
    String? department = _profileData?.department;
    String? commune = _profileData?.commune;
    String? userAddress = _currentUser?.address;
    
    List<String> addressParts = [];
    
    if (commune?.isNotEmpty == true) addressParts.add(commune!);
    if (department?.isNotEmpty == true) addressParts.add(department!);
    if (city?.isNotEmpty == true) addressParts.add(city!);
    if (country?.isNotEmpty == true) addressParts.add(country!);
    
    if (addressParts.isNotEmpty) {
      return addressParts.join(', ');
    }
    
    if (userAddress?.isNotEmpty == true) {
      return userAddress!;
    }
    
    return 'Non renseignée';
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _getPhotoStatus() {
    String? imageUrl = _profileData?.photo ?? _currentUser?.avatar;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      return 'Non définie (avatar généré)';
    }
    
    return 'Définie';
  }

  // 🎯 MÉTHODES DE NAVIGATION
  void _navigateToEditProfile() async {
    print('🔄 Navigation vers édition profil');
    
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProfilePage(user: _currentUser!),
      ),
    );
    
    if (result == true) {
      _loadUserProfile();
    }
  }

  void _navigateToStoreManagement() {
    print('🔄 Navigation vers gestion boutique');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Gestion boutique - En développement')),
    );
  }

  void _navigateToStatistics() {
    print('🔄 Navigation vers statistiques marchand');
    
    if (_currentUser!.isMerchant) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MerchantStatsPage(),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Accès réservé aux marchands'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  void _navigateToFavorites() {
    print('🔄 Navigation vers favoris');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Favoris - En développement')),
    );
  }

  void _navigateToOrders() {
    print('🔄 Navigation vers commandes');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const OrdersPage(),
      ),
    );
  }

  void _navigateToSettings() {
    print('🔄 Navigation vers paramètres');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Paramètres - En développement')),
    );
  }

  void _navigateToHelp() {
    print('🔄 Navigation vers aide');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aide & Support - En développement')),
    );
  }

  void _navigateToPrivacy() {
    print('🔄 Navigation vers confidentialité');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Confidentialité - En développement')),
    );
  }

  void _navigateToAbout() {
    print('🔄 Navigation vers à propos');
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('À propos - En développement')),
    );
  }

  // 🔥 MÉTHODE CORRIGÉE POUR LA DÉCONNEXION
  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Déconnexion', style: AppTextStyles.heading1.copyWith(fontSize: 18)),
        content: Text('Êtes-vous sûr de vouloir vous déconnecter ?', style: AppTextStyles.subtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Annuler', style: AppTextStyles.buttonTextSecondary),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context); // Ferme la dialog
              
              try {
                // Effectuer la déconnexion
                await _authService.logout();
                
                // Afficher le message de succès
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Déconnexion réussie'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
                
                print('🔄 Déconnexion réussie');
                
                // 🔥 REDIRECTION VERS LOGIN EN VIDANT LA PILE DE NAVIGATION
                if (mounted) {
                  Navigator.pushNamedAndRemoveUntil(
                    context, 
                    '/login', 
                    (route) => false, // Supprime toutes les routes précédentes
                  );
                }
                
              } catch (e) {
                print('❌ Erreur lors de la déconnexion: $e');
                
                // Afficher un message d'erreur
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Erreur lors de la déconnexion: ${e.toString()}'),
                      backgroundColor: AppColors.error,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            child: Text(
              'Déconnexion', 
              style: AppTextStyles.buttonTextSecondary.copyWith(color: AppColors.error),
            ),
          ),
        ],
      ),
    );
  }
}