import 'package:edurise/core/theme/app_colors.dart';
import 'package:edurise/core/theme/app_text_styles.dart';
import 'package:flutter/material.dart';
import 'package:edurise/core/theme/app_radius.dart';

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  const PrimaryButton({super.key, required this.text, required this.onPressed});
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.white, // text/icon color
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ), // remove shadow
        ),
        child: Text(text, style: AppTextStyles.button),
      ),
    );
  }
}
