import 'package:flutter/material.dart';
import 'package:voxa/widgets/chat/chat_list_item.dart';

class MessageTypeIcon extends StatelessWidget {
  final MessageType type;
  const MessageTypeIcon({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    switch (type) {
      case MessageType.image:
        return const Icon(Icons.image, size: 16, color: Color(0xFF667781));
      case MessageType.video:
        return const Icon(Icons.videocam, size: 16, color: Color(0xFF667781));
      case MessageType.voice:
        return const Icon(Icons.mic, size: 16, color: Color(0xFF667781));
      case MessageType.document:
        return const Icon(
          Icons.insert_drive_file,
          size: 16,
          color: Color(0xFF667781),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
