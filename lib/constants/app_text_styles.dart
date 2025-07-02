import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTextStyles {
  static const TextStyle heading1 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.gray800,
  );
   
  static const TextStyle subtitle = TextStyle(
    fontSize: 14,
    color: AppColors.gray600,
    height: 1.4,
  );
   
  static const TextStyle buttonText = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.white,
  );
   
  static const TextStyle buttonTextSecondary = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.gray700,
  );

  // 🔥 AJOUTEZ CETTE LIGNE :
  static const TextStyle caption = TextStyle(
    fontSize: 12,
    color: AppColors.gray500,
    height: 1.3,
  );
}