import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../profile/profile_avatar.dart';

class ContactTile extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onTap;
  final bool isMe;

  const ContactTile({
    super.key,
    required this.user,
    required this.onTap,
    this.isMe = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          ProfileAvatar(
            photoUrl: user.photoUrl,
            initial: user.initial,
            radius: 24,
          ),
          if (user.isOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 13,
                height: 13,
                decoration: BoxDecoration(
                  color: AppColors.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
              ),
            ),
        ],
      ),
      title: Text(
        isMe ? '${user.displayName} (You)' : user.displayName,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        isMe
            ? 'Message yourself'
            : (user.phoneNumber.isNotEmpty ? user.phoneNumber : user.about),
        style: const TextStyle(fontSize: 13.5, color: AppColors.secondaryText),
      ),
      trailing: const Icon(
        Icons.chat_bubble_outline,
        color: AppColors.secondary,
        size: 20,
      ),
    );
  }
}
