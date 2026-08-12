import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/conversation.dart';
import '../../models/user_profile.dart';
import '../../viewmodels/chat_list_viewmodel.dart';
import '../../widgets/chat/chat_list_item.dart';
import 'chat_screen.dart';

class ArchivedChatsScreen extends StatefulWidget {
  const ArchivedChatsScreen({super.key});

  @override
  State<ArchivedChatsScreen> createState() => _ArchivedChatsScreenState();
}

class _ArchivedChatsScreenState extends State<ArchivedChatsScreen> {
  final ChatListViewModel _viewModel = ChatListViewModel();

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final local = date.toLocal();
    final difference = now.difference(local);

    if (difference.inDays == 0 && now.day == local.day) {
      final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
      final minute = local.minute.toString().padLeft(2, '0');
      final period = local.hour >= 12 ? 'PM' : 'AM';
      return '$hour:$minute $period';
    } else if (difference.inDays == 1 ||
        (difference.inDays == 0 && now.day != local.day)) {
      return 'Yesterday';
    } else {
      return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year.toString().substring(2)}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _viewModel.currentUid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Archived chats'),
      ),
      body: StreamBuilder<List<Conversation>>(
        stream: _viewModel.chatsStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final allChats = snapshot.data!;
          final archivedChats = allChats
              .where((chat) => chat.isArchivedFor(uid))
              .toList();

          // Every 1:1 chat partner is, by definition, a contact.
          final contactUids = allChats
              .where((chat) => !chat.isGroup)
              .map((chat) => chat.otherUser?.uid)
              .whereType<String>()
              .toSet();

          if (archivedChats.isEmpty) {
            return const Center(
              child: Text(
                'No archived chats',
                style: TextStyle(color: AppColors.secondaryText),
              ),
            );
          }

          return ListView.separated(
            itemCount: archivedChats.length,
            separatorBuilder: (context, index) =>
                const Divider(height: 1, indent: 85, endIndent: 16),
            itemBuilder: (context, index) {
              final chat = archivedChats[index];
              final isGroup = chat.isGroup;
              final otherUser = chat.otherUser;

              final name = isGroup
                  ? (chat.groupName ?? 'Group')
                  : (otherUser?.displayName ?? 'Voxa User');
              final photoUrl = isGroup
                  ? chat.groupPhoto
                  : (otherUser?.canSeePhoto(uid, viewerContacts: contactUids) ==
                          true
                      ? otherUser?.photoUrl
                      : null);
              final isOnline = isGroup
                  ? false
                  : (otherUser != null &&
                      otherUser.canSeeOnlineStatus(uid,
                          viewerContacts: contactUids) &&
                      otherUser.isOnline);
              final unreadCount = chat.unreadCountFor(uid);

              return Dismissible(
                key: Key(chat.id),
                direction: DismissDirection.startToEnd,
                onDismissed: (direction) {
                  _viewModel.archiveChat(chat.id, false);
                },
                background: Container(
                  color: AppColors.accent,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: const Icon(Icons.unarchive, color: Colors.white),
                ),
                child: ChatListItem(
                  name: name,
                  avatarUrl: photoUrl,
                  lastMessage: chat.lastMessage.isNotEmpty
                      ? chat.lastMessage
                      : 'Tap to start chat',
                  time: _formatTime(chat.lastMessageTime ?? chat.updatedAt),
                  unreadCount: unreadCount,
                  isOnline: isOnline,
                  status: MessageStatus.none,
                  type: MessageType.text,
                  avatarColor: AppColors.secondary,
                  isPinned: chat.isPinnedFor(uid),
                  onTap: () {
                    final recipient = isGroup
                        ? UserProfile(
                            uid: chat.id,
                            phoneNumber: '',
                            displayName: name,
                            photoUrl: photoUrl,
                            about: chat.groupDescription ?? '',
                            isOnline: true,
                          )
                        : otherUser;

                    if (recipient == null) return;

                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          conversationId: chat.id,
                          recipient: recipient,
                          isGroup: isGroup,
                        ),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
