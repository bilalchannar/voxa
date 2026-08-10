import 'package:flutter/material.dart';

import 'chat_list_item.dart';

class MessageStatusIcon extends StatelessWidget {
  final MessageStatus status;
  const MessageStatusIcon({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    if (status == MessageStatus.none) return const SizedBox.shrink();

    if (status == MessageStatus.sent) {
      return const Icon(Icons.done, size: 16, color: Color(0xFF667781));
    }

    return Icon(
      Icons.done_all,
      size: 16,
      color: status == MessageStatus.seen
          ? Colors.blue
          : const Color(0xFF667781),
    );
  }
}
