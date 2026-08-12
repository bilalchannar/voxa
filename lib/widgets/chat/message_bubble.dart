import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/media_saver_service.dart';
import '../../core/services/settings_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/message.dart';
import '../../screens/chat/video_player_screen.dart';
import 'voice_message_bubble.dart';

class MessageBubble extends StatelessWidget {
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
    if (message.replyToText == null || message.replyToText!.isEmpty) {
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
            message.replyToSender ?? 'Reply',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppColors.accent,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            message.replyToText!,
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
    if (message.reactions.isEmpty) return const SizedBox.shrink();

    final reactionList = message.reactions.values.toSet().toList();

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
    if (message.isDeleted) {
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
              fontSize: fontSize - 1,
              fontStyle: FontStyle.italic,
              color: isMe ? Colors.white70 : AppColors.secondaryText,
            ),
          ),
        ],
      );
    }

    final mediaUrl = message.mediaUrl ?? '';

    switch (message.type) {
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
            if (message.content.isNotEmpty &&
                message.content != '📷 Photo') ...[
              const SizedBox(height: 6),
              Text(
                message.content,
                style: TextStyle(fontSize: fontSize - 1),
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
                      title: message.content.isNotEmpty &&
                              message.content != '🎥 Video'
                          ? message.content
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
            if (message.content.isNotEmpty &&
                message.content != '🎥 Video') ...[
              const SizedBox(height: 6),
              Text(
                message.content,
                style: TextStyle(fontSize: fontSize - 1),
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
              color: isMe
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
                        message.fileName ?? 'Document',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: fontSize - 1,
                        ),
                      ),
                      if (message.fileSize != null)
                        Text(
                          _formatFileSize(message.fileSize),
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
        return VoiceMessageBubble(message: message, isMe: isMe);

      default:
        return Text(
          message.content,
          style: TextStyle(fontSize: fontSize, height: 1.3),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (message.isDeletedFor(currentUid)) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColor = isSelected
        ? AppColors.accent.withValues(alpha: 0.3)
        : (isMe
              ? (isDark ? AppColors.secondary : const Color(0xFFDCF8C6))
              : (isDark ? AppColors.darkElevated : Colors.white));

    final textColor = isMe
        ? (isDark ? Colors.white : AppColors.primaryText)
        : (isDark ? Colors.white : AppColors.primaryText);

    final isStarred = message.isStarredBy(currentUid);

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
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
              bottomLeft: isMe
                  ? const Radius.circular(12)
                  : const Radius.circular(2),
              bottomRight: isMe
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
                isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildReplySnippet(),
              DefaultTextStyle(
                style: TextStyle(color: textColor),
                child: _buildMediaContent(context),
              ),
              if (!message.isDeleted) _buildReactions(),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (message.isEdited && !message.isDeleted) ...[
                    const Text(
                      'edited ',
                      style: TextStyle(
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                        color: AppColors.secondaryText,
                      ),
                    ),
                  ],
                  if (isStarred && !message.isDeleted) ...[
                    const Icon(Icons.star, size: 12, color: Colors.amber),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    _formatTime(message.createdAt),
                    style: TextStyle(
                      color: isMe
                          ? (isDark ? Colors.white70 : AppColors.secondaryText)
                          : AppColors.secondaryText,
                      fontSize: 11,
                    ),
                  ),
                  if (isMe && !message.isDeleted) ...[
                    const SizedBox(width: 4),
                    if (message.isPending)
                      const Icon(
                        Icons.access_time,
                        size: 13,
                        color: AppColors.secondaryText,
                      )
                    else
                      Icon(
                        message.status == 'seen' ? Icons.done_all : Icons.done,
                        size: 15,
                        color: message.status == 'seen'
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
