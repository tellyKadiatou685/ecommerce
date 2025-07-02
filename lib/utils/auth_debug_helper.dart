// lib/utils/auth_debug_helper.dart
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class AuthDebugHelper {
  /// Méthode pour déboguer l'état de l'authentification
  static Future<void> debugAuthState() async {
    try {
      print('🔍 ===== DÉBOGAGE AUTHENTIFICATION =====');
      
      final prefs = await SharedPreferences.getInstance();
      
      // 1. Vérifier toutes les clés stockées
      final allKeys = prefs.getKeys();
      print('📦 Clés dans SharedPreferences: $allKeys');
      
      // 2. Vérifier le token
      final token = prefs.getString('token');
      print('🔑 Token présent: ${token != null}');
      if (token != null) {
        print('🔑 Token (début): ${token.substring(0, token.length > 50 ? 50 : token.length)}...');
        print('🔑 Longueur du token: ${token.length}');
        
        // Vérifier la structure du JWT
        try {
          final parts = token.split('.');
          print('🔑 Parties du JWT: ${parts.length} (doit être 3)');
          
          if (parts.length == 3) {
            // Décoder le payload
            final payload = json.decode(
              utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
            );
            print('🔑 Payload JWT: $payload');
            
            final exp = payload['exp'] as int?;
            if (exp != null) {
              final expirationTime = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
              final now = DateTime.now();
              print('🔑 Expiration: $expirationTime');
              print('🔑 Maintenant: $now');
              print('🔑 Expiré: ${now.isAfter(expirationTime)}');
              print('🔑 Temps restant: ${expirationTime.difference(now)}');
            }
          }
        } catch (e) {
          print('❌ Erreur décodage JWT: $e');
        }
      } else {
        print('❌ Aucun token trouvé dans SharedPreferences');
      }
      
      // 3. Vérifier les données utilisateur
      final userStr = prefs.getString('user');
      print('👤 User présent: ${userStr != null}');
      if (userStr != null) {
        try {
          final userData = json.decode(userStr);
          print('👤 User data: $userData');
        } catch (e) {
          print('❌ Erreur décodage user: $e');
        }
      }
      
      // 4. Vérifier d'autres clés possibles
      final accessToken = prefs.getString('access_token');
      final authToken = prefs.getString('auth_token');
      final jwtToken = prefs.getString('jwt_token');
      
      print('🔑 access_token: ${accessToken != null}');
      print('🔑 auth_token: ${authToken != null}');
      print('🔑 jwt_token: ${jwtToken != null}');
      
      print('🔍 =========================================');
    } catch (e) {
      print('❌ Erreur lors du débogage: $e');
    }
  }
  
  /// Force la sauvegarde d'un token de test
  static Future<void> setTestToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Token JWT de test (expiré dans 1h)
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final exp = now + 3600; // +1 heure
      
      // Header
      final header = base64Url.encode(utf8.encode(json.encode({
        "alg": "HS256",
        "typ": "JWT"
      })));
      
      // Payload
      final payload = base64Url.encode(utf8.encode(json.encode({
        "userId": 1,
        "email": "test@example.com",
        "iat": now,
        "exp": exp
      })));
      
      // Signature bidon
      final signature = base64Url.encode(utf8.encode("test_signature"));
      
      final testToken = '$header.$payload.$signature';
      
      await prefs.setString('token', testToken);
      await prefs.setString('user', json.encode({
        "id": 1,
        "email": "test@example.com",
        "name": "Test User"
      }));
      
      print('✅ Token de test sauvegardé');
      await debugAuthState();
    } catch (e) {
      print('❌ Erreur sauvegarde token test: $e');
    }
  }
  
  /// Nettoie toutes les données d'auth
  static Future<void> clearAuthData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('token');
      await prefs.remove('user');
      await prefs.remove('access_token');
      await prefs.remove('auth_token');
      await prefs.remove('jwt_token');
      
      print('✅ Données d\'authentification nettoyées');
    } catch (e) {
      print('❌ Erreur nettoyage: $e');
    }
  }
}