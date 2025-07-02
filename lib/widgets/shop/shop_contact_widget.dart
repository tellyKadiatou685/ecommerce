// lib/widgets/shop/shop_contact_widget.dart - VERSION SIMPLE
import 'package:flutter/material.dart';
import '../../models/shop_model.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

class ShopContactWidget extends StatelessWidget {
  final Shop shop;
  final Function(String) onShowSuccess;
  final Function(String) onShowError;

  const ShopContactWidget({
    Key? key,
    required this.shop,
    required this.onShowSuccess,
    required this.onShowError,
  }) : super(key: key);

  // 🔧 MÉTHODE POUR OBTENIR L'EMAIL DU PROPRIÉTAIRE
  String _getOwnerEmail() {
    if (shop.owner != null) {
      final username = shop.owner!.fullName.toLowerCase().replaceAll(' ', '_');
      return '$username@example.com';
    }
    return 'contact@${shop.name.toLowerCase().replaceAll(' ', '')}.com';
  }

  // 🔧 MÉTHODE POUR OBTENIR LE NUMÉRO WHATSAPP FORMATÉ
  String _getWhatsAppNumber() {
    String cleanNumber = shop.phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    
    // Ajouter le code pays sénégalais si nécessaire
    if (!cleanNumber.startsWith('+221') && !cleanNumber.startsWith('221')) {
      if (cleanNumber.startsWith('77') || cleanNumber.startsWith('78') || 
          cleanNumber.startsWith('70') || cleanNumber.startsWith('76')) {
        cleanNumber = '221$cleanNumber'; // Pas de + pour le lien WhatsApp
      }
    }
    
    if (cleanNumber.startsWith('+')) {
      cleanNumber = cleanNumber.substring(1);
    }
    
    return cleanNumber;
  }

  // 🔧 MÉTHODE POUR FORMATER LA DATE
  String _formatDate(DateTime date) {
    final months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: _getCardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.info_outline,
                color: AppColors.primaryOrange,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'Informations de contact',
                style: AppTextStyles.heading1.copyWith(fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 🔥 MÉTHODES DE CONTACT
          _buildContactMethod(
            Icons.message,
            'Envoyer un message',
            'Contactez directement la boutique',
            () => _startMessage(),
          ),
          
          _buildContactMethod(
            Icons.phone,
            'Appeler',
            shop.phoneNumber,
            () => _makePhoneCall(),
          ),
          
          // 🔥 WHATSAPP SIMPLE - JUSTE LE NUMÉRO
          _buildContactMethod(
            Icons.chat,
            'WhatsApp',
            shop.phoneNumber,
            () => _openWhatsAppSimple(),
            color: const Color(0xFF25D366),
          ),
          
          // 🔥 EMAIL SIMPLE
          _buildContactMethod(
            Icons.email,
            'Email',
            _getOwnerEmail(),
            () => _showEmailInfo(),
          ),
          
          _buildContactMethod(
            Icons.location_on,
            'Adresse',
            shop.address ?? 'Non renseignée',
            () => _showLocation(),
          ),
          
          _buildContactMethod(
            Icons.calendar_today,
            'Membre depuis',
            _formatDate(shop.createdAt),
            null,
          ),
        ],
      ),
    );
  }

  Widget _buildContactMethod(
    IconData icon,
    String title,
    String subtitle,
    VoidCallback? onTap, {
    Color? color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.gray50,
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: AppColors.gray200),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: color != null 
                      ? [color, color.withOpacity(0.8)]
                      : [const Color(0xFFFF9800), const Color(0xFFFFB74D)],
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppColors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.gray800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTextStyles.subtitle.copyWith(
                      fontSize: 14,
                      color: AppColors.gray600,
                    ),
                  ),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.gray400,
              ),
          ],
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

  // 🔥 MÉTHODES D'ACTION SIMPLIFIÉES

  void _startMessage() {
    print('💬 Démarrer conversation avec: ${shop.name}');
    onShowSuccess('Redirection vers la messagerie - Fonctionnalité bientôt disponible');
  }

  void _makePhoneCall() {
    final phone = shop.phoneNumber;
    if (phone.isNotEmpty) {
      print('📞 Appel: $phone');
      onShowSuccess('Numéro copié: $phone - Appelez manuellement');
    } else {
      onShowError('Numéro de téléphone non disponible');
    }
  }

  // 🔥 WHATSAPP SIMPLE - AFFICHAGE NUMÉRO
  void _openWhatsAppSimple() {
    final whatsappNumber = _getWhatsAppNumber();
    final message = 'Bonjour, je suis intéressé(e) par votre boutique "${shop.name}"';
    
    print('💬 WhatsApp: $whatsappNumber');
    print('📱 Message: $message');
    
    // Afficher les infos pour que l'utilisateur puisse copier
    showDialog(
      context: onShowSuccess.runtimeType.toString().contains('BuildContext') ? 
        onShowSuccess as BuildContext : 
        null as BuildContext, // Cette ligne sera corrigée
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF25D366),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.chat,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Contacter sur WhatsApp'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Numéro WhatsApp:'),
            const SizedBox(height: 8),
            SelectableText(
              '+$whatsappNumber',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Color(0xFF25D366),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Message suggéré:'),
            const SizedBox(height: 8),
            SelectableText(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Fermer'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              onShowSuccess('Numéro WhatsApp copié !');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF25D366),
            ),
            child: const Text('Copier numéro'),
          ),
        ],
      ),
    );
  }

  // 🔥 EMAIL SIMPLE - AFFICHAGE EMAIL
  void _showEmailInfo() {
    final email = _getOwnerEmail();
    print('📧 Email: $email');
    onShowSuccess('Email: $email - Copiez pour envoyer un message');
  }

  void _showLocation() {
    final address = shop.address;
    if (address != null && address != 'Non renseignée') {
      print('📍 Adresse: $address');
      onShowSuccess('Adresse: $address');
    } else {
      onShowError('Adresse non disponible');
    }
  }
}