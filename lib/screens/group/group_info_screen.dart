import 'package:flutter/material.dart';

import '../../core/services/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/voxa_snackbar.dart';
import '../../models/conversation.dart';
import '../../models/user_profile.dart';
import '../../widgets/profile/profile_avatar.dart';

class GroupInfoScreen extends StatefulWidget {
  final String conversationId;

  const GroupInfoScreen({super.key, required this.conversationId});

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  final FirebaseService _firebaseService = FirebaseService();

  List<UserProfile> _members = [];
  Set<String> _contactUids = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMembers();
  }

  Future<void> _loadMembers() async {
    try {
      final chatSnap = await _firebaseService
          .conversationStream(widget.conversationId)
          .first;
      final conv = Conversation.fromSnapshot(chatSnap);
      final members = await _firebaseService.getUsersByIds(conv.participants);
      final contacts = await _firebaseService.getContactUids();
      if (mounted) {
        setState(() {
          _members = members;
          _contactUids = contacts;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAddMembersSheet(Conversation conv) async {
    final allUsers = await _firebaseService.getAllUsers();
    final nonMembers = allUsers
        .where((u) => !conv.participants.contains(u.uid))
        .toList();

    if (!mounted) return;

    final selected = <String>{};

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.7,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Add Members',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: selected.isEmpty
                        ? null
                        : () async {
                            Navigator.pop(sheetCtx);
                            await _firebaseService.addGroupMembers(
                              widget.conversationId,
                              selected.toList(),
                            );
                            _loadMembers();
                            if (mounted) {
                              VoxaSnackBar.success(
                                context,
                                'Members added successfully!',
                              );
                            }
                          },
                    child: const Text('Add'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: nonMembers.isEmpty
                    ? const Center(
                        child: Text(
                          'All contacts are already in this group.',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                      )
                    : ListView.builder(
                        itemCount: nonMembers.length,
                        itemBuilder: (context, index) {
                          final user = nonMembers[index];
                          final isSel = selected.contains(user.uid);
                          return CheckboxListTile(
                            value: isSel,
                            onChanged: (val) {
                              setSheetState(() {
                                if (val == true) {
                                  selected.add(user.uid);
                                } else {
                                  selected.remove(user.uid);
                                }
                              });
                            },
                            secondary: ProfileAvatar(
                              photoUrl: user.canSeePhoto(
                                      _firebaseService.currentUid,
                                      viewerContacts: _contactUids)
                                  ? user.photoUrl
                                  : null,
                              initial: user.initial,
                              radius: 18,
                            ),
                            title: Text(user.displayName),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberOptions({
    required UserProfile member,
    required Conversation conv,
    required bool isMeAdmin,
  }) {
    final currentUid = _firebaseService.currentUid;
    if (member.uid == currentUid || !isMeAdmin) return;

    final isTargetAdmin = conv.isAdmin(member.uid);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: Icon(
                isTargetAdmin ? Icons.remove_moderator : Icons.security,
                color: AppColors.secondary,
              ),
              title: Text(
                isTargetAdmin ? 'Dismiss as Admin' : 'Make Group Admin',
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                if (isTargetAdmin) {
                  await _firebaseService.demoteGroupAdmin(
                    widget.conversationId,
                    member.uid,
                  );
                } else {
                  await _firebaseService.promoteGroupAdmin(
                    widget.conversationId,
                    member.uid,
                  );
                }
                _loadMembers();
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove, color: AppColors.danger),
              title: Text(
                'Remove ${member.displayName}',
                style: const TextStyle(color: AppColors.danger),
              ),
              onTap: () async {
                Navigator.pop(sheetCtx);
                await _firebaseService.removeGroupMember(
                  widget.conversationId,
                  member.uid,
                );
                _loadMembers();
                if (mounted) {
                  VoxaSnackBar.success(
                    context,
                    '${member.displayName} removed.',
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _leaveGroup() async {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Leave Group'),
        content: const Text('Are you sure you want to leave this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _firebaseService.leaveGroup(widget.conversationId);
              if (mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
                VoxaSnackBar.show(context, message: 'You left the group.');
              }
            },
            child: const Text(
              'Leave',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _firebaseService.currentUid;

    return Scaffold(
      appBar: AppBar(title: const Text('Group Info')),
      body: StreamBuilder(
        stream: _firebaseService.conversationStream(widget.conversationId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.secondary),
            );
          }

          final conv = Conversation.fromSnapshot(snapshot.data!);
          final isMeAdmin = conv.isAdmin(currentUid);

          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              children: [
                Center(
                  child: ProfileAvatar(
                    photoUrl: conv.groupPhoto,
                    initial: conv.groupName?.isNotEmpty == true
                        ? conv.groupName![0].toUpperCase()
                        : 'G',
                    radius: 48,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  conv.groupName ?? 'Group',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${conv.participants.length} members',
                  style: const TextStyle(color: AppColors.secondaryText),
                ),
                if (conv.groupDescription?.isNotEmpty == true) ...[
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      conv.groupDescription!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.secondaryText),
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Divider(),
                if (isMeAdmin)
                  ListTile(
                    leading: const Icon(
                      Icons.person_add,
                      color: AppColors.accent,
                    ),
                    title: const Text(
                      'Add Members',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    onTap: () => _showAddMembersSheet(conv),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Group Members (${_members.length})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ),
                ),
                _isLoading
                    ? const Padding(
                        padding: EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                          color: AppColors.secondary,
                        ),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _members.length,
                        itemBuilder: (context, index) {
                          final member = _members[index];
                          final isAdmin = conv.isAdmin(member.uid);
                          final isMe = member.uid == currentUid;

                          return ListTile(
                            onTap: () => _showMemberOptions(
                              member: member,
                              conv: conv,
                              isMeAdmin: isMeAdmin,
                            ),
                            leading: ProfileAvatar(
                              photoUrl: member.canSeePhoto(
                                      currentUid,
                                      viewerContacts: _contactUids)
                                  ? member.photoUrl
                                  : null,
                              initial: member.initial,
                              radius: 20,
                            ),
                            title: Text(
                              isMe
                                  ? '${member.displayName} (You)'
                                  : member.displayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text(member.phoneNumber),
                            trailing: isAdmin
                                ? Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(
                                        alpha: 0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Group Admin',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: AppColors.accent,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
                const Divider(),
                ListTile(
                  leading: const Icon(
                    Icons.exit_to_app,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Leave Group',
                    style: TextStyle(
                      color: AppColors.danger,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: _leaveGroup,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
