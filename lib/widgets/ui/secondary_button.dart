import 'package:flutter/material.dart';
import '../../constants/app_colors.dart';
import '../../constants/app_text_styles.dart';

class SecondaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;
  final EdgeInsets? margin;

  const SecondaryButton({
    Key? key,
    required this.text,
    required this.onPressed,
    this.margin,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 24),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: AppColors.white,
        border: Border.all(
          color: AppColors.gray200,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onPressed,
          splashColor: AppColors.primaryOrangeLight,
          highlightColor: AppColors.primaryOrangeLight.withOpacity(0.1),
          child: Container(
            alignment: Alignment.center,
            child: Text(
              text,
              style: AppTextStyles.buttonTextSecondary,
            ),
          ),
        ),
      ),
    );
  }
}