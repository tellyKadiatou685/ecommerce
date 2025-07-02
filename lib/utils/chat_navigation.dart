// lib/utils/chat_navigation.dart
import 'package:flutter/material.dart';
import '../screens/chat_screen.dart';
import '../screens/conversations_screen.dart';

class ChatNavigation {
  /// Navigation vers la liste des conversations
  static void navigateToConversations(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const ConversationsScreen(),
      ),
    );
  }

  /// Navigation directe vers un chat avec un utilisateur spécifique
  static void navigateToChat(
    BuildContext context, {
    required int userId,
    required String userName,
    String? userPhoto,
    bool isOnline = false,
  }) {
    print('🔥 [CHAT_NAVIGATION] Navigation vers chat:');
    print('  - User ID: $userId');
    print('  - User Name: $userName');
    print('  - User Photo: $userPhoto');
    print('  - Is Online: $isOnline');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ChatScreen(
          partnerId: userId,
          partnerName: userName,
          partnerPhoto: userPhoto,
          isOnline: isOnline,
        ),
      ),
    );
  }

  /// Navigation avec animation slide
  static void navigateToChatWithSlide(
    BuildContext context, {
    required int userId,
    required String userName,
    String? userPhoto,
    bool isOnline = false,
  }) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ChatScreen(
          partnerId: userId,
          partnerName: userName,
          partnerPhoto: userPhoto,
          isOnline: isOnline,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOut;

          var tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );

          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }
}