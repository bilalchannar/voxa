import 'package:flutter/material.dart';

import '../../core/services/call_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/voxa_snackbar.dart';
import '../../models/call_model.dart';
import '../../models/user_profile.dart';
import '../../screens/call/call_screen.dart';
import '../profile/profile_avatar.dart';

class CallsView extends StatefulWidget {
  const CallsView({super.key});

  @override
  State<CallsView> createState() => _CallsViewState();
}

class _CallsViewState extends State<CallsView> {
  final CallService _callService = CallService.instance;
  final FirebaseService _firebaseService = FirebaseService();
  Set<String> _contactUids = {};

  @override
  void initState() {
    super.initState();
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    try {
      final contacts = await _firebaseService.getContactUids();
      if (mounted) setState(() => _contactUids = contacts);
    } catch (_) {
      // Non-fatal: without contacts, "contacts"-only photos stay hidden.
    }
  }

  Future<void> _redialCall(CallModel call, String currentUid) async {
    final caller = await _firebaseService.getUserProfile();
    if (caller == null || !mounted) return;

    final targetUid = call.otherUid(currentUid);
    final targetName = call.otherName(currentUid);
    final targetPhoto = call.otherPhoto(currentUid);

    final receiver = UserProfile(
      uid: targetUid,
      phoneNumber: '',
      displayName: targetName,
      photoUrl: targetPhoto,
      about: '',
      isOnline: true,
    );

    final newCall = await _callService.makeCall(
      receiver: receiver,
      caller: caller,
      isVideoCall: call.isVideoCall,
    );

    if (newCall != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(call: newCall, isIncoming: false),
        ),
      );
    }
  }

  void _confirmDeleteCall(CallModel call) {
    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Delete Call Log'),
        content: const Text('Remove this call from your history?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogCtx);
              await _callService.deleteCallHistoryItem(call.callId);
              if (mounted) {
                VoxaSnackBar.success(context, 'Call log deleted.');
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime? dt) {
    if (dt == null) return '';
    final local = dt.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '${local.day}/${local.month}/${local.year} at $hour:$minute $period';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '';
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return ' ($m:$s)';
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = _callService.currentUid;

    return StreamBuilder<List<CallModel>>(
      stream: _callService.callHistoryStream(currentUid),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Could not load call history.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: AppColors.secondary),
          );
        }

        final calls = snapshot.data!;
        if (calls.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_ic_call_outlined,
                  size: 64,
                  color: AppColors.secondaryText,
                ),
                const SizedBox(height: 16),
                const Text(
                  'No call history',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryText,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Your recent audio and video calls will appear here.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: calls.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final call = calls[index];
            final isMeCaller = call.isMeCaller(currentUid);
            final isMissed = call.isMissed(currentUid);

            IconData statusIcon;
            Color statusColor;

            if (isMissed) {
              statusIcon = Icons.call_missed;
              statusColor = AppColors.danger;
            } else if (isMeCaller) {
              statusIcon = Icons.call_made;
              statusColor = AppColors.accent;
            } else {
              statusIcon = Icons.call_received;
              statusColor = Colors.blue;
            }

            final targetUid = call.otherUid(currentUid);
            final fallbackName = call.otherName(currentUid);
            final fallbackPhoto = call.otherPhoto(currentUid);

            return StreamBuilder<UserProfile?>(
              stream: _firebaseService.profileStream(uid: targetUid),
              builder: (context, profileSnap) {
                final user = profileSnap.data;
                final displayName = user?.displayName ?? fallbackName;
                final photoUrl = user?.photoUrl ?? fallbackPhoto;
                final initial = displayName.isNotEmpty ? displayName[0].toUpperCase() : 'V';

                return Dismissible(
                  key: Key(call.callId),
                  direction: DismissDirection.endToStart,
                  onDismissed: (direction) async {
                    await _callService.deleteCallHistoryItem(call.callId);
                    if (mounted) {
                      VoxaSnackBar.success(context, 'Call log deleted.');
                    }
                  },
                  background: Container(
                    color: AppColors.danger,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: const Icon(Icons.delete, color: Colors.white),
                  ),
                  child: ListTile(
                    onTap: () => _redialCall(call, currentUid),
                    onLongPress: () => _confirmDeleteCall(call),
                    leading: ProfileAvatar(
                      photoUrl: user?.canSeePhoto(currentUid,
                                  viewerContacts: _contactUids) ==
                              true
                          ? photoUrl
                          : null,
                      initial: initial,
                      radius: 24,
                    ),
                    title: Text(
                      displayName,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isMissed ? AppColors.danger : AppColors.primaryText,
                      ),
                    ),
                    subtitle: Row(
                      children: [
                        Icon(statusIcon, size: 16, color: statusColor),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            '${_formatTimestamp(call.timestamp)}${_formatDuration(call.duration)}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.secondaryText,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    trailing: IconButton(
                      icon: Icon(
                        call.isVideoCall ? Icons.videocam : Icons.phone,
                        color: AppColors.secondary,
                      ),
                      onPressed: () => _redialCall(call, currentUid),
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}
