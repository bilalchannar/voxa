import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Circular profile avatar that shows the user's Cloudinary photo when
/// available and gracefully falls back to a generated initial avatar when the
/// photo is missing or fails to load.
class ProfileAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initial;
  final double radius;

  /// Optional override for the fallback background; defaults to a branded tint.
  final Color? backgroundColor;

  const ProfileAvatar({
    super.key,
    required this.photoUrl,
    required this.initial,
    this.radius = 28,
    this.backgroundColor,
  });

  bool get _hasPhoto => photoUrl != null && photoUrl!.isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final diameter = radius * 2;
    final bg = backgroundColor ?? AppColors.secondary.withValues(alpha: 0.18);

    return SizedBox(
      width: diameter,
      height: diameter,
      child: ClipOval(
        child: _hasPhoto
            ? Image.network(
                photoUrl!,
                width: diameter,
                height: diameter,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return _FallbackAvatar(
                    initial: initial,
                    diameter: diameter,
                    radius: radius,
                    background: bg,
                    showSpinner: true,
                  );
                },
                errorBuilder: (context, error, stack) => _FallbackAvatar(
                  initial: initial,
                  diameter: diameter,
                  radius: radius,
                  background: bg,
                ),
              )
            : _FallbackAvatar(
                initial: initial,
                diameter: diameter,
                radius: radius,
                background: bg,
              ),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final String initial;
  final double diameter;
  final double radius;
  final Color background;
  final bool showSpinner;

  const _FallbackAvatar({
    required this.initial,
    required this.diameter,
    required this.radius,
    required this.background,
    this.showSpinner = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: diameter,
      height: diameter,
      alignment: Alignment.center,
      color: background,
      child: showSpinner
          ? SizedBox(
              width: radius * 0.6,
              height: radius * 0.6,
              child: const CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.secondary,
              ),
            )
          : Text(
              initial,
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.8,
              ),
            ),
    );
  }
}
