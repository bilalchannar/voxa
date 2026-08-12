import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/services/call_service.dart';
import '../../core/services/firebase_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/voxa_snackbar.dart';
import '../../models/app_settings.dart';
import '../../models/message.dart';
import '../../models/user_profile.dart';
import '../../viewmodels/chat_viewmodel.dart';
import '../../widgets/chat/message_bubble.dart';
import '../../widgets/chat/voice_recording_bar.dart';
import '../../widgets/profile/profile_avatar.dart';
import '../call/call_screen.dart';
import '../group/group_info_screen.dart';
import 'chat_media_gallery_screen.dart';

class ChatScreen extends StatefulWidget {
  final String conversationId;
  final UserProfile recipient;
  final bool isGroup;

  const ChatScreen({
    super.key,
    required this.conversationId,
    required this.recipient,
    this.isGroup = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  late final ChatViewModel _viewModel;
  final FirebaseService _firebaseService = FirebaseService();
  final SettingsService _settingsService = SettingsService();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ImagePicker _picker = ImagePicker();

  bool _canSend = false;
  bool _isRecordingVoice = false;
  bool _isSearching = false;
  String _searchQuery = '';

  Message? _replyToMessage;
  Message? _editingMessage;
  final Set<String> _selectedMessageIds = {};

  @override
  void initState() {
    super.initState();
    _viewModel = ChatViewModel(
      conversationId: widget.conversationId,
      receiverId: widget.recipient.uid,
    );
    _viewModel.markMessagesAsSeen();
    _messageController.addListener(_onTextChanged);
    _searchController.addListener(_onSearchChanged);
  }

  void _onTextChanged() {
    final hasText = _messageController.text.trim().isNotEmpty;
    if (hasText != _canSend) {
      setState(() => _canSend = hasText);
    }
    if (hasText) {
      _viewModel.onUserTyping();
    }
  }

  void _onSearchChanged() {
    setState(() => _searchQuery = _searchController.text.trim().toLowerCase());
  }

  @override
  void dispose() {
    _viewModel.stopTyping();
    _messageController.removeListener(_onTextChanged);
    _searchController.removeListener(_onSearchChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 60,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleSendText() async {
    final text = _messageController.text;
    if (text.trim().isEmpty) return;

    if (_editingMessage != null) {
      final editMsg = _editingMessage!;
      _messageController.clear();
      setState(() => _editingMessage = null);
      await _firebaseService.editMessage(
        conversationId: widget.conversationId,
        messageId: editMsg.messageId,
        newContent: text,
      );
      return;
    }

    final replyId = _replyToMessage?.messageId;
    final replyText = _replyToMessage?.content;
    final replySender = _replyToMessage?.senderId == _viewModel.currentUid
        ? 'You'
        : widget.recipient.displayName;

    _messageController.clear();
    setState(() => _replyToMessage = null);

    final success = await _viewModel.sendMessage(
      text,
      replyToId: replyId,
      replyToText: replyText,
      replyToSender: replySender,
    );

    if (success) {
      _scrollToBottom();
    }
  }

  void _showMessageOptions(Message msg, bool isMe) {
    final currentUid = _viewModel.currentUid;
    final isStarred = msg.isStarredBy(currentUid);

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: ['👍', '❤️', '😂', '😮', '😢', '🙏'].map((emoji) {
                    return GestureDetector(
                      onTap: () async {
                        Navigator.pop(sheetCtx);
                        await _firebaseService.toggleReaction(
                          conversationId: widget.conversationId,
                          messageId: msg.messageId,
                          emoji: emoji,
                        );
                      },
                      child: Text(emoji, style: const TextStyle(fontSize: 28)),
                    );
                  }).toList(),
                ),
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.reply, color: AppColors.secondary),
                title: const Text('Reply'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _replyToMessage = msg);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy, color: AppColors.secondary),
                title: const Text('Copy'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  Clipboard.setData(ClipboardData(text: msg.content));
                  VoxaSnackBar.success(context, 'Message copied to clipboard.');
                },
              ),
              ListTile(
                leading: Icon(
                  isStarred ? Icons.star_border : Icons.star,
                  color: Colors.amber,
                ),
                title: Text(isStarred ? 'Unstar Message' : 'Star Message'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _firebaseService.toggleStarMessage(
                    conversationId: widget.conversationId,
                    messageId: msg.messageId,
                    isStarred: !isStarred,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.forward, color: AppColors.secondary),
                title: const Text('Forward'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  _forwardMessage(msg);
                },
              ),
              if (isMe && msg.type == 'text' && !msg.isDeleted)
                ListTile(
                  leading: const Icon(Icons.edit, color: AppColors.accent),
                  title: const Text('Edit'),
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    setState(() {
                      _editingMessage = msg;
                      _messageController.text = msg.content;
                    });
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.delete_outline,
                  color: AppColors.danger,
                ),
                title: const Text('Delete for Me'),
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  await _firebaseService.deleteMessageForMe(
                    conversationId: widget.conversationId,
                    messageId: msg.messageId,
                  );
                },
              ),
              if (isMe && !msg.isDeleted)
                ListTile(
                  leading: const Icon(
                    Icons.delete_forever,
                    color: AppColors.danger,
                  ),
                  title: const Text(
                    'Delete for Everyone',
                    style: TextStyle(color: AppColors.danger),
                  ),
                  onTap: () async {
                    Navigator.pop(sheetCtx);
                    await _firebaseService.deleteMessageForEveryone(
                      conversationId: widget.conversationId,
                      messageId: msg.messageId,
                    );
                  },
                ),
              ListTile(
                leading: const Icon(
                  Icons.select_all,
                  color: AppColors.secondary,
                ),
                title: const Text('Select Multiple'),
                onTap: () {
                  Navigator.pop(sheetCtx);
                  setState(() => _selectedMessageIds.add(msg.messageId));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _forwardMessage(Message msg) async {
    final allUsers = await _firebaseService.getAllUsers();
    final contactUids = await _firebaseService.getContactUids();
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetCtx) => SafeArea(
        child: ListView.builder(
          itemCount: allUsers.length,
          itemBuilder: (itemCtx, index) {
            final target = allUsers[index];
            return ListTile(
              leading: ProfileAvatar(
                photoUrl: target.canSeePhoto(_viewModel.currentUid,
                        viewerContacts: contactUids)
                    ? target.photoUrl
                    : null,
                initial: target.initial,
                radius: 18,
              ),
              title: Text(target.displayName),
              onTap: () async {
                final targetName = target.displayName;
                Navigator.pop(sheetCtx);
                final fwdChatId = await _firebaseService.createOrGetChat(
                  target.uid,
                );
                await _firebaseService.sendMessage(
                  conversationId: fwdChatId,
                  receiverId: target.uid,
                  content: msg.content,
                );
                if (mounted) {
                  VoxaSnackBar.success(
                    context,
                    'Message forwarded to $targetName.',
                  );
                }
              },
            );
          },
        ),
      ),
    );
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.image, color: AppColors.secondary),
              title: const Text('Photo'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndPreviewMedia('image');
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam, color: Colors.purple),
              title: const Text('Video'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndPreviewMedia('video');
              },
            ),
            ListTile(
              leading: const Icon(
                Icons.insert_drive_file,
                color: Colors.orange,
              ),
              title: const Text('Document'),
              onTap: () {
                Navigator.pop(sheetContext);
                _pickAndPreviewMedia('document');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndPreviewMedia(String type) async {
    File? file;
    String fileName = '';
    int fileSize = 0;

    try {
      if (type == 'image') {
        final picked = await _picker.pickImage(source: ImageSource.gallery);
        if (picked != null) {
          file = File(picked.path);
          fileName = picked.name;
          fileSize = await file.length();
        }
      } else if (type == 'video') {
        final picked = await _picker.pickVideo(source: ImageSource.gallery);
        if (picked != null) {
          file = File(picked.path);
          fileName = picked.name;
          fileSize = await file.length();
        }
      } else if (type == 'document') {
        final result = await FilePicker.pickFiles();
        if (result != null && result.files.single.path != null) {
          file = File(result.files.single.path!);
          fileName = result.files.single.name;
          fileSize = result.files.single.size;
        }
      }
    } catch (e) {
      debugPrint('[ChatScreen] File picking error: $e');
    }

    if (file == null || !mounted) return;

    const maxSizeBytes = 50 * 1024 * 1024;
    if (fileSize > maxSizeBytes) {
      VoxaSnackBar.error(
        context,
        'File size exceeds the 50MB limit. Please select a smaller file.',
      );
      return;
    }

    _showMediaPreviewDialog(
      file: file,
      type: type,
      fileName: fileName,
      fileSize: fileSize,
    );
  }

  void _showMediaPreviewDialog({
    required File file,
    required String type,
    required String fileName,
    required int fileSize,
  }) {
    final captionController = TextEditingController();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) => AlertDialog(
        title: Text('Send ${type.toUpperCase()}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (type == 'image')
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(file, height: 180, fit: BoxFit.cover),
                )
              else if (type == 'video')
                Container(
                  height: 120,
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Icon(
                      Icons.play_circle_fill,
                      size: 48,
                      color: Colors.white,
                    ),
                  ),
                )
              else
                ListTile(
                  leading: const Icon(
                    Icons.insert_drive_file,
                    size: 36,
                    color: AppColors.secondary,
                  ),
                  title: Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB',
                  ),
                ),
              const SizedBox(height: 12),
              TextField(
                controller: captionController,
                decoration: const InputDecoration(
                  hintText: 'Add a caption (optional)...',
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final caption = captionController.text;
              Navigator.pop(dialogCtx);
              await _executeMediaSend(
                file: file,
                type: type,
                caption: caption,
                fileName: fileName,
                fileSize: fileSize,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _executeMediaSend({
    required File file,
    required String type,
    required String caption,
    required String fileName,
    required int fileSize,
  }) async {
    final success = await _viewModel.sendMedia(
      file: file,
      type: type,
      caption: caption,
      fileName: fileName,
      fileSize: fileSize,
    );

    if (!mounted) return;

    if (success) {
      _scrollToBottom();
    } else {
      final err = _viewModel.uploadError ?? 'Failed to send media.';
      VoxaSnackBar.error(context, err);
    }
  }

  String _formatStatusSubtitle(UserProfile recipient, bool isRecipientTyping) {
    if (recipient.uid == _viewModel.currentUid) {
      return 'Message yourself';
    }
    if (isRecipientTyping) return 'typing...';

    // In a 1:1 chat the recipient is, by definition, a contact of the viewer
    // (they share a direct conversation), so "contacts"-level privacy applies.
    final contacts = {recipient.uid};
    final viewerUid = _viewModel.currentUid;
    final allowOnline =
        recipient.canSeeOnlineStatus(viewerUid, viewerContacts: contacts);
    final allowLastSeen =
        recipient.canSeeLastSeen(viewerUid, viewerContacts: contacts);

    if (allowOnline && recipient.isOnline) return 'Online';

    if (allowLastSeen && recipient.lastSeen != null) {
      final now = DateTime.now();
      final lastSeen = recipient.lastSeen!.toLocal();
      final timeStr = DateFormat('hh:mm a').format(lastSeen);

      final diff = now.difference(lastSeen);
      if (diff.inDays == 0 && now.day == lastSeen.day) {
        return 'today at $timeStr';
      } else if (diff.inDays == 1 ||
          (diff.inDays == 0 && now.day != lastSeen.day)) {
        return 'yesterday at $timeStr';
      } else {
        return '${DateFormat('dd/MM/yy').format(lastSeen)} at $timeStr';
      }
    }

    return '';
  }

  Future<void> _startAudioCall() async {
    final caller = await _viewModel.getCurrentUserProfile();
    if (caller == null || !mounted) return;

    final call = await CallService.instance.makeCall(
      receiver: widget.recipient,
      caller: caller,
      isVideoCall: false,
    );

    if (call != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(call: call, isIncoming: false),
        ),
      );
    }
  }

  Future<void> _startVideoCall() async {
    final caller = await _viewModel.getCurrentUserProfile();
    if (caller == null || !mounted) return;

    final call = await CallService.instance.makeCall(
      receiver: widget.recipient,
      caller: caller,
      isVideoCall: true,
    );

    if (call != null && mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => CallScreen(call: call, isIncoming: false),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isMultiSelect = _selectedMessageIds.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        leading: isMultiSelect
            ? IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _selectedMessageIds.clear()),
              )
            : null,
        actions: isMultiSelect
            ? [
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () async {
                    for (final id in _selectedMessageIds) {
                      await _firebaseService.deleteMessageForMe(
                        conversationId: widget.conversationId,
                        messageId: id,
                      );
                    }
                    setState(() => _selectedMessageIds.clear());
                  },
                ),
              ]
            : [
                if (!_isSearching) ...[
                  if (widget.recipient.uid != _viewModel.currentUid) ...[
                    IconButton(
                      icon: const Icon(Icons.videocam, size: 22),
                      onPressed: _startVideoCall,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone, size: 20),
                      onPressed: _startAudioCall,
                      visualDensity: VisualDensity.compact,
                      padding: EdgeInsets.zero,
                    ),
                  ],
                  PopupMenuButton<String>(
                    onSelected: (val) async {
                      if (val == 'search') {
                        setState(() => _isSearching = true);
                      } else if (val == 'media') {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ChatMediaGalleryScreen(
                              conversationId: widget.conversationId,
                            ),
                          ),
                        );
                      } else if (val == 'clear') {
                        await _firebaseService.clearChat(widget.conversationId);
                        if (!context.mounted) return;
                        VoxaSnackBar.show(context, message: 'Chat cleared.');
                      } else if (val == 'unread') {
                        await _firebaseService.markChatUnread(
                          widget.conversationId,
                        );
                        if (!context.mounted) return;
                        VoxaSnackBar.show(
                          context,
                          message: 'Marked as unread.',
                        );
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'search',
                        child: Text('Search'),
                      ),
                      const PopupMenuItem(
                        value: 'media',
                        child: Text('Media, links, & docs'),
                      ),
                      const PopupMenuItem(
                        value: 'unread',
                        child: Text('Mark as unread'),
                      ),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Text('Clear chat'),
                      ),
                    ],
                  ),
                ],
              ],
        title: _isSearching
            ? TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search messages...',
                  border: InputBorder.none,
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      setState(() {
                        _isSearching = false;
                        _searchController.clear();
                      });
                    },
                  ),
                ),
              )
            : (isMultiSelect
                  ? Text('${_selectedMessageIds.length} selected')
                  : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: _viewModel.conversationStream(),
                      builder: (context, convSnap) {
                        return StreamBuilder<UserProfile?>(
                          stream: _firebaseService.profileStream(
                            uid: widget.recipient.uid,
                          ),
                          builder: (context, userSnap) {
                            final user = userSnap.data ?? widget.recipient;
                            final convData = convSnap.data?.data() ?? {};
                            final typingMap =
                                (convData['typingUsers']
                                    as Map<String, dynamic>?) ??
                                {};
                            final isRecipientTyping =
                                (typingMap[user.uid] as bool?) ?? false;

                            final statusSubtitle = widget.isGroup
                                ? 'Tap for group info'
                                : _formatStatusSubtitle(
                                  user,
                                  isRecipientTyping,
                                );

                            return InkWell(
                              onTap: widget.isGroup
                                  ? () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => GroupInfoScreen(
                                            conversationId: widget.conversationId,
                                          ),
                                        ),
                                      );
                                    }
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 4,
                                  horizontal: 4,
                                ),
                                child: Row(
                                  children: [
                                      ProfileAvatar(
                                      photoUrl: user.canSeePhoto(
                                            _viewModel.currentUid,
                                            viewerContacts: {user.uid},
                                          )
                                          ? user.photoUrl
                                          : null,
                                      initial: user.initial,
                                      radius: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            user.displayName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          if (statusSubtitle.isNotEmpty)
                                            Text(
                                              statusSubtitle,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: isRecipientTyping
                                                    ? FontWeight.bold
                                                    : FontWeight.normal,
                                                color: isRecipientTyping
                                                    ? AppColors.accent
                                                    : (statusSubtitle == 'Online'
                                                          ? AppColors.accent
                                                          : AppColors.secondaryText),
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    )),
      ),
      body: SafeArea(
        child: StreamBuilder<ChatSettings>(
          stream: _settingsService.chatsStream(),
          builder: (context, settingsSnap) {
            final chatSettings = settingsSnap.data ?? const ChatSettings();
            final bgColor = chatSettings.wallpaperColor != 0
                ? Color(chatSettings.wallpaperColor)
                : null;
            final fontSize = chatSettings.fontSize.fontSize;

            return Container(
              width: double.infinity,
              height: double.infinity,
              color: bgColor,
              child: ListenableBuilder(
                listenable: _viewModel,
                builder: (context, _) {
                  return Column(
                    children: [
                      if (_viewModel.isUploading)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          child: const Row(
                            children: [
                              SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppColors.secondary,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Uploading media to Cloudinary...',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      Expanded(
                        child: StreamBuilder<List<Message>>(
                          stream: _viewModel.messagesStream(),
                          builder: (context, snapshot) {
                            if (snapshot.hasError) {
                              return const Center(
                                child: Text(
                                  'Could not load messages.',
                                  style:
                                      TextStyle(color: AppColors.secondaryText),
                                ),
                              );
                            }

                            if (!snapshot.hasData) {
                              return const Center(
                                child: CircularProgressIndicator(
                                  color: AppColors.secondary,
                                ),
                              );
                            }

                            var messages = snapshot.data!;
                            if (_searchQuery.isNotEmpty) {
                              messages = messages
                                  .where(
                                    (m) => m.content.toLowerCase().contains(
                                      _searchQuery,
                                    ),
                                  )
                                  .toList();
                            }

                            if (messages.isEmpty) {
                              return Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.chat_bubble_outline,
                                      size: 56,
                                      color: AppColors.secondaryText,
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _searchQuery.isNotEmpty
                                          ? 'No matching messages found.'
                                          : 'Say Hi to ${widget.recipient.displayName} 👋',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }

                            _viewModel.markMessagesAsSeen();
                            WidgetsBinding.instance.addPostFrameCallback(
                              (_) => _scrollToBottom(),
                            );

                            return ListView.builder(
                              controller: _scrollController,
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              itemCount: messages.length,
                              itemBuilder: (context, index) {
                                final msg = messages[index];
                                final isMe =
                                    msg.senderId == _viewModel.currentUid;
                                final isSel = _selectedMessageIds.contains(
                                  msg.messageId,
                                );

                                return Dismissible(
                                  key: Key(msg.messageId),
                                  direction: DismissDirection.endToStart,
                                  confirmDismiss: (direction) async {
                                    setState(() => _replyToMessage = msg);
                                    return false; // Don't actually dismiss
                                  },
                                  background: Container(
                                    alignment: Alignment.centerRight,
                                    padding: const EdgeInsets.only(right: 20),
                                    child: const Icon(
                                      Icons.reply,
                                      color: AppColors.secondary,
                                    ),
                                  ),
                                  child: MessageBubble(
                                    message: msg,
                                    isMe: isMe,
                                    currentUid: _viewModel.currentUid,
                                    isSelected: isSel,
                                    fontSize: fontSize,
                                    onTap: () {
                                      if (isMultiSelect) {
                                        setState(() {
                                          if (isSel) {
                                            _selectedMessageIds.remove(
                                              msg.messageId,
                                            );
                                          } else {
                                            _selectedMessageIds.add(
                                              msg.messageId,
                                            );
                                          }
                                        });
                                      }
                                    },
                                    onLongPress:
                                        () => _showMessageOptions(msg, isMe),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                      if (_replyToMessage != null || _editingMessage != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          color: AppColors.secondary.withValues(alpha: 0.1),
                          child: Row(
                            children: [
                              Icon(
                                _editingMessage != null
                                    ? Icons.edit
                                    : Icons.reply,
                                color: AppColors.accent,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _editingMessage != null
                                      ? 'Editing: ${_editingMessage!.content}'
                                      : 'Replying to: ${_replyToMessage!.content}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.close, size: 18),
                                onPressed: () {
                                  setState(() {
                                    _replyToMessage = null;
                                    _editingMessage = null;
                                    _messageController.clear();
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      if (_isRecordingVoice)
                        VoiceRecordingBar(
                          onSend: (audioFile) async {
                            setState(() => _isRecordingVoice = false);
                            final len = await audioFile.length();
                            await _executeMediaSend(
                              file: audioFile,
                              type: 'voice',
                              caption: '',
                              fileName: 'voice_message.m4a',
                              fileSize: len,
                            );
                          },
                          onCancel: () {
                            setState(() => _isRecordingVoice = false);
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 3,
                                offset: const Offset(0, -1),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.attach_file,
                                  color: AppColors.secondary,
                                ),
                                onPressed:
                                    _viewModel.isUploading
                                        ? null
                                        : _showAttachmentOptions,
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  focusNode: _messageFocusNode,
                                  textCapitalization:
                                      TextCapitalization.sentences,
                                  keyboardType: TextInputType.multiline,
                                  // When "Enter key sends" is on, the keyboard
                                  // shows a send action and Enter fires
                                  // onSubmitted; otherwise Enter inserts a
                                  // newline (multiline composing).
                                  textInputAction: chatSettings.enterKeySends
                                      ? TextInputAction.send
                                      : TextInputAction.newline,
                                  onSubmitted: chatSettings.enterKeySends
                                      ? (_) {
                                          _handleSendText();
                                          // Keep the composer focused so the
                                          // keyboard stays up for the next line.
                                          _messageFocusNode.requestFocus();
                                        }
                                      : null,
                                  maxLines: 4,
                                  minLines: 1,
                                  decoration: InputDecoration(
                                    hintText:
                                        _editingMessage != null
                                            ? 'Edit message...'
                                            : 'Type a message...',
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 10,
                                    ),
                                    filled: true,
                                    fillColor: Theme.of(
                                      context,
                                    ).scaffoldBackgroundColor,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(24),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_canSend)
                                IconButton.filled(
                                  onPressed:
                                      _viewModel.isUploading
                                          ? null
                                          : _handleSendText,
                                  icon: const Icon(Icons.send, size: 20),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.accent,
                                    foregroundColor: Colors.white,
                                  ),
                                )
                              else
                                IconButton.filled(
                                  onPressed:
                                      _viewModel.isUploading
                                          ? null
                                          : () {
                                            setState(
                                              () => _isRecordingVoice = true,
                                            );
                                          },
                                  icon: const Icon(Icons.mic, size: 20),
                                  style: IconButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                            ],
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
