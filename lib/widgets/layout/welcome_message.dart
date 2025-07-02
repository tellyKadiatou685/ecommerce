import 'package:flutter/material.dart';
import '../../constants/app_text_styles.dart';

class WelcomeMessage extends StatelessWidget {
  final String title;
  final String subtitle;

  const WelcomeMessage({
    Key? key,
    this.title = "Bienvenue !",
    this.subtitle = "Découvrez une nouvelle expérience",
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        children: [
          Text(
            title,
            style: AppTextStyles.heading1,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: AppTextStyles.subtitle,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}