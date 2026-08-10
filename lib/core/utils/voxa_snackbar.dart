import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class VoxaSnackBar {
  VoxaSnackBar._();

  static void show(
    BuildContext context, {
    required String message,
    IconData icon = Icons.info_outline,
    Color? iconColor,
    SnackBarAction? action,
    Duration duration = const Duration(seconds: 3),
  }) {
    if (!context.mounted) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark
        ? AppColors.darkElevated
        : const Color(0xFF2C3E50);
    final foregroundColor = Colors.white;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          elevation: 6,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          backgroundColor: backgroundColor,
          duration: duration,
          action: action,
          content: Row(
            children: [
              Icon(icon, size: 20, color: iconColor ?? AppColors.secondary),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  message,
                  style: TextStyle(
                    color: foregroundColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
  }

  static void success(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_outline,
      iconColor: AppColors.accent,
    );
  }

  static void error(BuildContext context, String message) {
    show(
      context,
      message: message,
      icon: Icons.error_outline,
      iconColor: AppColors.danger,
    );
  }
}
