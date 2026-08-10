import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/firebase_service.dart';
import '../../core/theme/app_colors.dart';
import '../../models/message.dart';

class ChatMediaGalleryScreen extends StatelessWidget {
  final String conversationId;

  const ChatMediaGalleryScreen({super.key, required this.conversationId});

  @override
  Widget build(BuildContext context) {
    final FirebaseService firebaseService = FirebaseService();

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Media, Links & Docs'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Media'),
              Tab(text: 'Docs'),
              Tab(text: 'Links'),
            ],
          ),
        ),
        body: StreamBuilder<List<Message>>(
          stream: firebaseService.messagesStream(conversationId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Center(child: Text('Error loading media.'));
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              );
            }

            final messages = snapshot.data!;
            final mediaMsgs = messages
                .where((m) => m.type == 'image' || m.type == 'video')
                .toList();
            final docMsgs = messages
                .where((m) => m.type == 'document')
                .toList();
            final linkMsgs = messages
                .where(
                  (m) =>
                      m.content.contains('http://') ||
                      m.content.contains('https://'),
                )
                .toList();

            return TabBarView(
              children: [
                _buildMediaGrid(mediaMsgs),
                _buildDocsList(docMsgs),
                _buildLinksList(linkMsgs),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMediaGrid(List<Message> messages) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'No media shared yet.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 6,
        mainAxisSpacing: 6,
      ),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final msg = messages[index];
        if (msg.type == 'image' && msg.mediaUrl != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(msg.mediaUrl!, fit: BoxFit.cover),
          );
        }
        return Container(
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Center(
            child: Icon(Icons.play_circle_fill, size: 36, color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildDocsList(List<Message> messages) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'No documents shared yet.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      separatorBuilder: (_, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final msg = messages[index];
        final sizeMb = ((msg.fileSize ?? 0) / (1024 * 1024)).toStringAsFixed(1);
        return ListTile(
          leading: const Icon(
            Icons.insert_drive_file,
            color: AppColors.secondary,
            size: 32,
          ),
          title: Text(
            msg.fileName ?? 'Document',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text('$sizeMb MB'),
          onTap: () async {
            if (msg.mediaUrl != null) {
              final uri = Uri.parse(msg.mediaUrl!);
              if (await canLaunchUrl(uri)) await launchUrl(uri);
            }
          },
        );
      },
    );
  }

  Widget _buildLinksList(List<Message> messages) {
    if (messages.isEmpty) {
      return const Center(
        child: Text(
          'No links shared yet.',
          style: TextStyle(color: AppColors.secondaryText),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: messages.length,
      separatorBuilder: (_, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final msg = messages[index];
        final urlRegExp = RegExp(r'https?://[^\s]+');
        final match = urlRegExp.firstMatch(msg.content);
        final url = match?.group(0) ?? msg.content;

        return ListTile(
          leading: const Icon(Icons.link, color: AppColors.accent, size: 32),
          title: Text(url, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            msg.content,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          onTap: () async {
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) await launchUrl(uri);
          },
        );
      },
    );
  }
}
