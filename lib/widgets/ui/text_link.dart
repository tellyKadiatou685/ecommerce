
import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';

class TextLink extends StatelessWidget {
  final String text;
  final VoidCallback onTap;
  final Color? color;
  final FontWeight? fontWeight;

  const TextLink({
    Key? key,
    required this.text,
    required this.onTap,
    this.color,
    this.fontWeight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: color ?? AppColors.primaryOrange,
          fontWeight: fontWeight ?? FontWeight.w500,
          fontSize: 14,
          decoration: TextDecoration.none,
        ),
      ),
    );
  }
}
