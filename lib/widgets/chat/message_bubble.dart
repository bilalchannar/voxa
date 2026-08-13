import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/media_saver_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/media_loader.dart';
import '../../models/message.dart';
import '../../screens/chat/video_player_screen.dart';
import 'voice_message_bubble.dart';

class MessageBubble extends StatefulWidget {
  final Message message;
  final bool isMe;
  final String currentUid;
  final bool isSelected;
  final double fontSize;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const MessageBubble({
    super.key,
    required this.message,
    required this.isMe,
    required this.currentUid,
    this.isSelected = false,
    this.fontSize = 15,
    this.onTap,
    this.onLongPress,
  });

  @override
  State<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends State<MessageBubble> {
  bool _manualDownload = false;
  bool? _shouldAutoDownload;

  @override
  void initState() {
    super.initState();
    _checkAutoDownload();
  }

  Future<void> _checkAutoDownload() async {
    final result = await MediaLoader.shouldAutoDownload(widget.message.type);
    if (mounted) {
      setState(() => _shouldAutoDownload = result);
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _formatFileSize(int? bytes) {
    if (bytes == null || bytes == 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Future<void> _openMediaUrl(BuildContext context, String? url) async {
    if (url == null || url.isEmpty) return;
    final uri = Uri.parse(url);
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open media link.')),
        );
      }
    } catch (e) {
      debugPrint('[MessageBubble] openMediaUrl error: $e');
    }
  }

  Future<void> _saveMedia(
    BuildContext context, {
    required String? url,
    required bool isVideo,
  }) async {
    if (url == null || url.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Saving media...')),
    );

    // The "Media visibility" chat setting decides where the file lands:
    // gallery (visible) vs the app's private storage (hidden from gallery).
    final settings = await SettingsService().getChats();
    final result = await const MediaSaverService().saveFromUrl(
      url: url,
      mediaVisible: settings.mediaVisibility,
      isVideo: isVideo,
    );

    messenger.hideCurrentSnackBar();
    final String text;
    if (result.success) {
      text = result.location == MediaSaveLocation.gallery
          ? 'Saved to gallery'
          : 'Saved to app (hidden from gallery — Media visibility is off)';
    } else if (result.error == 'permission-denied') {
      text = 'Gallery permission denied. Enable it in Settings to save.';
    } else {
      text = 'Could not save media. Please try again.';
    }
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }

  void _showImageViewer(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.zero,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                      child: Text(
                        'Failed to load image.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    );
                  },
                ),
              ),
            ),
            Positioned(
              top: 40,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 28),
                onPressed: () => Navigator.pop(ctx),
              ),
            ),
            Positioned(
              top: 40,
              left: 16,
              child: IconButton(
                icon: const Icon(
                  Icons.download_rounded,
                  color: Colors.white,
                  size: 28,
                ),
                tooltip: 'Save to gallery',
                onPressed: () => _saveMedia(ctx, url: imageUrl, isVideo: false),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReplySnippet() {
    if (widget.message.replyToText == null || widget.message.replyToText!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(6),
        border: const Border(
          left: BorderSide(color: AppColors.accent, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.message.replyToSender ?? 'Reply',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            widget.message.replyToText!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReactions() {
    if (widget.message.reactions.isEmpty) return const SizedBox.shrink();

    final reactionList = widget.message.reactions.values.toSet().toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 4,
        children: reactionList.map((emoji) {
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(emoji, style: const TextStyle(fontSize: 12)),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMediaContent(BuildContext context) {
    if (widget.message.isDeleted) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.block,
            size: 14,
            color: AppColors.secondaryText,
          ),
          const SizedBox(width: 6),
          Text(
            'This message was deleted',
            style: TextStyle(
              fontSize: widget.fontSize - 1,
              fontStyle: FontStyle.italic,
              color: widget.isMe ? Colors.white70 : AppColors.secondaryText,
            ),
          ),
        ],
      );
    }

    final mediaUrl = widget.message.mediaUrl ?? '';
    final isAllowed = (_shouldAutoDownload ?? true) || _manualDownload || widget.isMe;

    if (!isAllowed && widget.message.type != 'text') {
       return _buildDownloadPlaceholder(widget.message.type);
    }

    switch (widget.message.type) {
      case 'image':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _showImageViewer(context, mediaUrl),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  mediaUrl,
                  width: 220,
                  height: 200,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return Container(
                      width: 220,
                      height: 200,
                      color: Colors.black12,
                      child: const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      width: 220,
                      height: 150,
                      color: Colors.black12,
                      child: const Center(
                        child: Icon(
                          Icons.broken_image,
                          size: 40,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            if (widget.message.content.isNotEmpty &&
                widget.message.content != '📷 Photo') ...[
              const SizedBox(height: 6),
              Text(
                widget.message.content,
                style: TextStyle(fontSize: widget.fontSize - 1),
              ),
            ],
          ],
        );

      case 'video':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => VideoPlayerScreen(
                      url: mediaUrl,
                      title: widget.message.content.isNotEmpty &&
                              widget.message.content != '🎥 Video'
                          ? widget.message.content
                          : 'Video',
                    ),
                  ),
                );
              },
              child: Container(
                width: 220,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    const Icon(
                      Icons.play_circle_fill,
                      size: 54,
                      color: Colors.white,
                    ),
                    Positioned(
                      bottom: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text(
                          'VIDEO',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (widget.message.content.isNotEmpty &&
                widget.message.content != '🎥 Video') ...[
              const SizedBox(height: 6),
              Text(
                widget.message.content,
                style: TextStyle(fontSize: widget.fontSize - 1),
              ),
            ],
          ],
        );

      case 'document':
        return GestureDetector(
          onTap: () => _openMediaUrl(context, mediaUrl),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: widget.isMe
                  ? Colors.black12
                  : AppColors.secondary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.insert_drive_file,
                  size: 36,
                  color: AppColors.secondary,
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.message.fileName ?? 'Document',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: widget.fontSize - 1,
                        ),
                      ),
                      if (widget.message.fileSize != null)
                        Text(
                          _formatFileSize(widget.message.fileSize),
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.secondaryText,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.download,
                  size: 20,
                  color: AppColors.secondaryText,
                ),
              ],
            ),
          ),
        );

      case 'voice':
        return VoiceMessageBubble(message: widget.message, isMe: widget.isMe);

      default:
        return Text(
          widget.message.content,
          style: TextStyle(fontSize: widget.fontSize, height: 1.3),
        );
    }
  }

  Widget _buildDownloadPlaceholder(String type) {
    final icon = type == 'image' 
        ? Icons.image 
        : (type == 'video' ? Icons.videocam : Icons.insert_drive_file);
    
    return InkWell(
      onTap: () => setState(() => _manualDownload = true),
      child: Container(
        width: 220,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.secondaryText),
            const SizedBox(height: 8),
            const Text(
              'Tap to download',
              style: TextStyle(fontSize: 12, color: AppColors.secondaryText),
            ),
            if (widget.message.fileSize != null)
              Text(
                _formatFileSize(widget.message.fileSize),
                style: const TextStyle(fontSize: 10, color: AppColors.secondaryText),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.message.isDeletedFor(widget.currentUid)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = widget.isSelected
        ? AppColors.accent.withValues(alpha: 0.3)
        : (widget.isMe
              ? (isDark ? AppColors.secondary : const Color(0xFFDCF8C6))
              : (isDark ? AppColors.darkElevated : Colors.white));

    final textColor = widget.isMe
        ? (isDark ? Colors.white : AppColors.primaryText)
        : (isDark ? Colors.white : AppColors.primaryText);

    final isStarred = widget.message.isStarredBy(widget.currentUid);

    return InkWell(
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: Align(
        alignment: widget.isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.78,
          ),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(12),
              topRight: const Radius.circular(12),
              bottomLeft: widget.isMe
                  ? const Radius.circular(12)
                  : const Radius.circular(2),
              bottomRight: widget.isMe
                  ? const Radius.circular(2)
                  : const Radius.circular(12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 2,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                widget.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReplySnippet(),
              DefaultTextStyle(
                style: TextStyle(color: textColor),
                child: _buildMediaContent(context),
              ),
              if (!widget.message.isDeleted) _buildReactions(),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.message.isEdited && !widget.message.isDeleted) ...[
                    const Text(
                      'edited ',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                  if (isStarred && !widget.message.isDeleted) ...[
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _formatTime(widget.message.createdAt),
                    style: TextStyle(
                      color: widget.isMe
                          ? (isDark ? Colors.white70 : AppColors.secondaryText)
                          : AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                  if (widget.isMe && !widget.message.isDeleted) ...[
                    const SizedBox(width: 4),
                    if (widget.message.isPending)
                      const Icon(
                        Icons.access_time,
                        size: 13,
                        color: AppColors.secondaryText,
                      )
                    else
                      Icon(
                        widget.message.status == 'seen' ? Icons.done_all : Icons.done,
                        size: 15,
                        color: widget.message.status == 'seen'
                            ? Colors.blue
                            : AppColors.secondaryText,
                      ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
