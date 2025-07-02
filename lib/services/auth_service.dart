// lib/services/auth_service.dart - VERSION FINALE CORRIGÉE
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_config.dart';

class AuthService {
  // Singleton pattern
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  // 🔧 ENDPOINTS CENTRALISÉS CORRIGÉS
  static String get checkEmailEndpoint => '${ApiConfig.baseUrl}/api/auth/check-email';
  static String get registerEndpoint => '${ApiConfig.baseUrl}/api/auth/register';
  static String get verifyEndpoint => '${ApiConfig.baseUrl}/api/auth/verify';
  static String get resendCodeEndpoint => '${ApiConfig.baseUrl}/api/auth/resend-verification';
  static String get profileEndpoint => '${ApiConfig.baseUrl}/api/auth/profile';
  
  // 🔥 URL CORRIGÉE : /api/authprofile → /api/auth/profile
  static String get updateProfileEndpoint => '${ApiConfig.baseUrl}/api/auth/profile';
  
  static String get testConnectionEndpoint => '${ApiConfig.baseUrl}/api/test';

  // Fonction de connexion (ne pas modifier - elle marche déjà)
  Future<LoginResponse> login(String email, String password) async {
    try {
      print('🔄 Tentative de connexion pour: $email');
      print('🌐 URL: ${ApiConfig.loginEndpoint}');
      
      final response = await http.post(
        Uri.parse(ApiConfig.loginEndpoint),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Cache-Control': 'no-cache',
          'Connection': 'close',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );

      print('📡 Status Code: ${response.statusCode}');
      print('📄 Response Body: ${response.body}');

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final loginResponse = LoginResponse.fromJson(data);
        
        // Sauvegarder le token si la connexion réussit
        if (loginResponse.token != null) {
          await _saveToken(loginResponse.token!);
          await _saveUser(loginResponse.user!);
        }
        
        return loginResponse;
      } else {
        // Gérer les erreurs spécifiques
        throw ApiError.fromJson(data);
      }
    } catch (e) {
      print('❌ Erreur de connexion: $e');
      if (e is ApiError) {
        rethrow;
      }
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur de connexion au serveur. Vérifiez votre connexion internet.',
      );
    }
  }

  // 🔧 CORRIGÉ : Récupérer le profil utilisateur
// Dans AuthService.getUserProfile() - LIGNE 88 à corriger
Future<ProfileData> getUserProfile() async {
  try {
    print('🔄 Récupération du profil');
    print('🌐 URL: $profileEndpoint');
    
    final token = await getToken();
    if (token == null) {
      throw ApiError(
        status: 'error',
        code: 'NOT_AUTHENTICATED',
        message: 'Non authentifié',
      );
    }
    
    final response = await http.get(
      Uri.parse(profileEndpoint),
      headers: {
        ...ApiConfig.defaultHeaders,
        'Authorization': 'Bearer $token',
        'Cache-Control': 'no-cache',
        'Connection': 'close',
      },
    );

    print('📊 Statut: ${response.statusCode}');
    print('📄 Response body: ${response.body}');

    final Map<String, dynamic> data = jsonDecode(response.body);

    if (response.statusCode == 200) {
      print('✅ Parsing ProfileData...');
      
      // 🔥 FIX PRINCIPAL : Extraire les données user d'abord
      if (data['user'] != null) {
        final Map<String, dynamic> userData = data['user'] as Map<String, dynamic>;
        print('👤 UserData à parser: $userData');
        print('📸 Photo dans userData: "${userData['photo']}"');
        
        final profileData = ProfileData.fromJson(userData); // ← CHANGEMENT ICI
        print('📸 Photo après parsing: "${profileData.photo}"');
        return profileData;
      } else {
        throw ApiError(
          status: 'error',
          code: 'NO_USER_DATA',
          message: 'Pas de données utilisateur dans la réponse',
        );
      }
    } else {
      print('❌ Erreur HTTP: ${response.statusCode}');
      throw ApiError.fromJson(data);
    }
  } catch (e) {
    print('❌ Erreur récupération profil: $e');
    if (e is ApiError) rethrow;
    throw ApiError(
      status: 'error',
      code: 'NETWORK_ERROR',
      message: 'Erreur lors de la récupération du profil',
    );
  }
}
  Future<ProfileData> updateUserProfile({
    String? firstName,
    String? lastName,
    String? email,
    String? phoneNumber,
    String? city,
    String? country,
    File? photo,
  }) async {
    try {
      print('🔄 Mise à jour du profil');
      print('🌐 URL: $updateProfileEndpoint');
      
      final token = await getToken();
      if (token == null) {
        throw ApiError(
          status: 'error',
          code: 'NOT_AUTHENTICATED',
          message: 'Non authentifié',
        );
      }

      final request = http.MultipartRequest(
        'PUT',
        Uri.parse(updateProfileEndpoint),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Cache-Control': 'no-cache',
        'Connection': 'close',
      });

      // Ajouter les champs modifiés
      if (firstName?.isNotEmpty == true) request.fields['firstName'] = firstName!;
      if (lastName?.isNotEmpty == true) request.fields['lastName'] = lastName!;
      if (email?.isNotEmpty == true) request.fields['email'] = email!;
      if (phoneNumber?.isNotEmpty == true) request.fields['phoneNumber'] = phoneNumber!;
      if (city?.isNotEmpty == true) request.fields['city'] = city!;
      if (country?.isNotEmpty == true) request.fields['country'] = country!;

      if (photo != null) {
        print('📸 Ajout de la photo au request');
        request.files.add(await http.MultipartFile.fromPath('photo', photo.path));
      }

      print('📤 Envoi de la requête de mise à jour...');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      print('📊 Statut mise à jour: ${response.statusCode}');
      print('📄 Response update: ${response.body}');

      final Map<String, dynamic> data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        print('✅ Mise à jour réussie !');
        final profileData = ProfileData.fromJson(data);
        print('📸 Nouvelle photo: "${profileData.photo}"');
        
        // Mettre à jour l'utilisateur local
        final currentUser = await getUser();
        if (currentUser != null) {
          final updatedUser = currentUser.copyWith(
            firstName: firstName,
            lastName: lastName,
            email: email,
            phone: phoneNumber,
          );
          await _saveUser(updatedUser);
        }
        
        return profileData;
      } else {
        print('❌ Erreur mise à jour: ${response.statusCode}');
        throw ApiError.fromJson(data);
      }
    } catch (e) {
      print('❌ Erreur mise à jour profil: $e');
      if (e is ApiError) rethrow;
      throw ApiError(
        status: 'error',
        code: 'NETWORK_ERROR',
        message: 'Erreur lors de la mise à jour du profil',
      );
    }
  }

  // Autres méthodes (registerUser, verifyCode, etc.) - gardez vos versions existantes
  
  // Sauvegarder le token (privé)
  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Sauvegarder l'utilisateur (privé)
  Future<void> _saveUser(User user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_data', jsonEncode(user.toJson()));
  }

  // Récupérer le token
  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Récupérer l'utilisateur
  Future<User?> getUser() async {
    final prefs = await SharedPreferences.getInstance();
    final userData = prefs.getString('user_data');
    if (userData != null) {
      return User.fromJson(jsonDecode(userData));
    }
    return null;
  }

  // Vérifier si l'utilisateur est connecté
  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }

  // Déconnexion
  Future<void> logout() async {
    print('🔄 Déconnexion de l\'utilisateur');
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
    await prefs.remove('user_data');
    print('✅ Utilisateur déconnecté avec succès');
  }

  // 🔧 CORRIGÉ : Tester la connexion au serveur
  Future<bool> testConnection() async {
    try {
      print('🧪 Test de connexion: $testConnectionEndpoint');
      
      final response = await http.get(
        Uri.parse(testConnectionEndpoint),
        headers: {
          ...ApiConfig.defaultHeaders,
          'Cache-Control': 'no-cache',
          'Connection': 'close',
        },
      ).timeout(const Duration(seconds: 10));
      
      print('📊 Test connexion statut: ${response.statusCode}');
      print('📄 Response body: ${response.body}');
      
      // ✅ Vérifier que la réponse est OK et contient le bon statut
      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(response.body);
          return data['status'] == 'success' && data['connection'] == 'ok';
        } catch (e) {
          // Si ce n'est pas du JSON, mais que le statut est 200, c'est OK
          return true;
        }
      }
      
      return false;
    } catch (e) {
      print('❌ Test de connexion échoué: $e');
      print('❌ Type d\'erreur: ${e.runtimeType}');
      return false;
    }
  }

  // 🔧 NOUVELLE MÉTHODE : Debug des URLs
  static void printAllEndpoints() {
    print('🔍 ===== DEBUG ENDPOINTS =====');
    print('Base URL: ${ApiConfig.baseUrl}');
    print('Login: ${ApiConfig.loginEndpoint}');
    print('Check Email: $checkEmailEndpoint');
    print('Register: $registerEndpoint');
    print('Verify: $verifyEndpoint');
    print('Resend: $resendCodeEndpoint');
    print('Profile: $profileEndpoint');
    print('Update: $updateProfileEndpoint');
    print('Test: $testConnectionEndpoint');
    print('🔍 ===========================');
  }
}