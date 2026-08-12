import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../models/conversation.dart';
import '../../models/user_profile.dart';
import '../../viewmodels/chat_list_viewmodel.dart';
import '../../screens/chat/chat_screen.dart';
import '../../widgets/chat/chat_filter_chip.dart';
import '../../widgets/chat/chat_list_item.dart';
import '../../screens/chat/archived_chats_screen.dart';
import '../../core/utils/voxa_snackbar.dart';

class ChatsView extends StatefulWidget {
  final String searchQuery;

  const ChatsView({super.key, this.searchQuery = ''});

  @override
  State<ChatsView> createState() => _ChatsViewState();
}

class _ChatsViewState extends State<ChatsView> {
  final ChatListViewModel _viewModel = ChatListViewModel();
  String _selectedFilter = 'All';

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

  void _showContextMenu(BuildContext context, Conversation chat) {
    final uid = _viewModel.currentUid;
    final isPinned = chat.isPinnedFor(uid);
    final isMuted = chat.isMutedFor(uid);
    final isArchived = chat.isArchivedFor(uid);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ListTile(
                leading: Icon(
                  isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                ),
                title: Text(isPinned ? 'Unpin chat' : 'Pin chat'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _viewModel.pinChat(chat.id, !isPinned);
                },
              ),
              ListTile(
                leading: Icon(
                  isMuted
                      ? Icons.notifications_off_outlined
                      : Icons.notifications_off,
                ),
                title: Text(
                  isMuted ? 'Unmute notifications' : 'Mute notifications',
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _viewModel.muteChat(chat.id, !isMuted);
                },
              ),
              ListTile(
                leading: Icon(
                  isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                ),
                title: Text(isArchived ? 'Unarchive chat' : 'Archive chat'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _viewModel.archiveChat(chat.id, !isArchived);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text(
                  'Delete chat',
                  style: TextStyle(color: AppColors.danger),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _confirmDelete(chat.id);
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );
    },
    );
  }

  void _confirmDelete(String chatId) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete chat?'),
        content: const Text('This conversation will be permanently removed.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _viewModel.deleteChat(chatId);
            },
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 60,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              ChatFilterChip(
                label: 'All',
                isSelected: _selectedFilter == 'All',
                onTap: () => setState(() => _selectedFilter = 'All'),
              ),
              ChatFilterChip(
                label: 'Unread',
                isSelected: _selectedFilter == 'Unread',
                onTap: () => setState(() => _selectedFilter = 'Unread'),
              ),
              ChatFilterChip(
                label: 'Groups',
                isSelected: _selectedFilter == 'Groups',
                onTap: () => setState(() => _selectedFilter = 'Groups'),
              ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<Conversation>>(
            stream: _viewModel.chatsStream(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.cloud_off,
                          size: 48,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Could not load conversations. Check your connection.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      ],
                    ),
                  ),
                );
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: AppColors.secondary),
                );
              }

              final uid = _viewModel.currentUid;
              final allChats = snapshot.data!;

              // Every 1:1 chat partner is, by definition, a contact of the
              // current user. Used to resolve "My Contacts" privacy locally.
              final contactUids = allChats
                  .where((chat) => !chat.isGroup)
                  .map((chat) => chat.otherUser?.uid)
                  .whereType<String>()
                  .toSet();

              final archivedChats = allChats.where((chat) => chat.isArchivedFor(uid)).toList();
              final activeChats = allChats.where((chat) => !chat.isArchivedFor(uid)).toList();

              final filteredChats = activeChats.where((chat) {
                if (widget.searchQuery.isNotEmpty) {
                  final isGroup = chat.isGroup;
                  final otherUser = chat.otherUser;
                  final name = isGroup
                      ? (chat.groupName ?? 'Group')
                      : (otherUser?.displayName ?? 'Voxa User');
                  final q = widget.searchQuery.toLowerCase();
                  final nameMatches = name.toLowerCase().contains(q);
                  final msgMatches = chat.lastMessage.toLowerCase().contains(q);
                  if (!nameMatches && !msgMatches) return false;
                }
                if (_selectedFilter == 'Unread') {
                  return chat.unreadCountFor(uid) > 0;
                }
                if (_selectedFilter == 'Groups') {
                  return chat.participants.length > 2;
                }
                return true;
              }).toList();

              if (filteredChats.isEmpty && archivedChats.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline,
                          size: 56,
                          color: AppColors.secondaryText,
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'No conversations yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Tap the message icon below to start a new chat.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.separated(
                itemCount: filteredChats.length + (archivedChats.isNotEmpty ? 1 : 0),
                separatorBuilder: (context, index) =>
                    const Divider(height: 1, indent: 85, endIndent: 16),
                itemBuilder: (context, index) {
                  if (archivedChats.isNotEmpty && index == 0) {
                    return ListTile(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ArchivedChatsScreen()),
                        );
                      },
                      leading: const SizedBox(
                        width: 54,
                        child: Icon(Icons.archive_outlined, color: AppColors.secondary),
                      ),
                      title: const Text(
                        'Archived',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      trailing: Text(
                        '${archivedChats.length}',
                        style: const TextStyle(color: AppColors.accent, fontWeight: FontWeight.bold),
                      ),
                    );
                  }

                  final chatIndex = archivedChats.isNotEmpty ? index - 1 : index;
                  final chat = filteredChats[chatIndex];
                  final isGroup = chat.isGroup;
                  final otherUser = chat.otherUser;

                  final name = isGroup
                      ? (chat.groupName ?? 'Group')
                      : (otherUser?.displayName ?? 'Voxa User');
                  final photoUrl = isGroup
                      ? chat.groupPhoto
                      : (otherUser?.canSeePhoto(uid, viewerContacts: contactUids) == true
                          ? otherUser?.photoUrl
                          : null);
                  final isOnline = isGroup
                      ? false
                      : (otherUser != null &&
                          otherUser.canSeeOnlineStatus(uid,
                              viewerContacts: contactUids) &&
                          otherUser.isOnline);
                  final unreadCount = chat.unreadCountFor(uid);

                  final isPinned = chat.isPinnedFor(uid);

                  return Dismissible(
                    key: Key(chat.id),
                    direction: DismissDirection.horizontal,
                    confirmDismiss: (direction) async {
                      if (direction == DismissDirection.startToEnd) {
                        // Pin/Unpin action
                        _viewModel.pinChat(chat.id, !isPinned);
                        return false; // Don't dismiss
                      } else {
                        // Archive action
                        _viewModel.archiveChat(chat.id, !chat.isArchivedFor(uid));
                        VoxaSnackBar.success(
                          context,
                          chat.isArchivedFor(uid)
                              ? 'Chat unarchived'
                              : 'Chat archived',
                        );
                        return true; // Dismiss to hide from main list
                      }
                    },
                    background: Container(
                      color: AppColors.accent,
                      alignment: Alignment.centerLeft,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            isPinned ? Icons.push_pin_outlined : Icons.push_pin,
                            color: Colors.white,
                          ),
                          Text(
                            isPinned ? 'Unpin' : 'Pin',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    secondaryBackground: Container(
                      color: AppColors.accent,
                      alignment: Alignment.centerRight,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            chat.isArchivedFor(uid)
                                ? Icons.unarchive_outlined
                                : Icons.archive_outlined,
                            color: Colors.white,
                          ),
                          Text(
                            chat.isArchivedFor(uid) ? 'Unarchive' : 'Archive',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    child: GestureDetector(
                      onLongPress: () => _showContextMenu(context, chat),
                      child: ChatListItem(
                        name: name,
                        avatarUrl: photoUrl,
                        lastMessage: chat.lastMessage.isNotEmpty
                            ? chat.lastMessage
                            : 'Tap to start chat',
                        time:
                            _formatTime(chat.lastMessageTime ?? chat.updatedAt),
                        unreadCount: unreadCount,
                        isOnline: isOnline,
                        status: MessageStatus.none,
                        type: MessageType.text,
                        avatarColor: AppColors.secondary,
                        isPinned: isPinned,
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
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
