import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/user_profile.dart';
import '../profile/profile_avatar.dart';

class ContactTile extends StatelessWidget {
  final UserProfile user;
  final VoidCallback onTap;
  final bool isMe;
  final String? currentUid;
  final Set<String> viewerContacts;

  const ContactTile({
    super.key,
    required this.user,
    required this.onTap,
    this.isMe = false,
    this.currentUid,
    this.viewerContacts = const <String>{},
  });

  String _subtitle() {
    if (isMe) return 'Message yourself';
    if (user.phoneNumber.isNotEmpty) return user.phoneNumber;
    // "About" respects the owner's About privacy setting.
    if (user.canSeeAbout(currentUid, viewerContacts: viewerContacts)) {
      return user.about;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final showOnlineDot =
        user.canSeeOnlineStatus(currentUid, viewerContacts: viewerContacts) &&
        user.isOnline;
    return ListTile(
      onTap: onTap,
      leading: Stack(
        children: [
          ProfileAvatar(
            photoUrl: user.canSeePhoto(currentUid, viewerContacts: viewerContacts)
                ? user.photoUrl
                : null,
            initial: user.initial,
            radius: 24,
          ),
          if (showOnlineDot)
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
        _subtitle(),
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
