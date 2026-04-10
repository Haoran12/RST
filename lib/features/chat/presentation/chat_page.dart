import 'package:flutter/material.dart';

import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/floating_composer.dart';
import '../../../shared/widgets/glass_panel_card.dart';
import '../../../shared/widgets/message_bubble.dart';
import '../../../shared/widgets/mode_chip.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/streaming_indicator.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();

  final List<_MessageItem> _messages = const [
    _MessageItem(
      role: 'assistant',
      content: 'RST MVP 脚手架已初始化，下一步可以接 Rust FFI。',
    ),
    _MessageItem(role: 'user', content: '依据文档，先把基础目录和导航搭起来。'),
    _MessageItem(
      role: 'assistant',
      content: '已完成 4 个主 Tab 与共享组件占位。',
      hidden: true,
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Column(
              children: [
                GlassPanelCard(
                  child: Row(
                    children: const [
                      ModeChip(mode: 'RST'),
                      SizedBox(width: 10),
                      StatusBadge(label: 'idle', color: AppColors.success),
                      Spacer(),
                      StreamingIndicator(label: '等待发送'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView.separated(
                    reverse: true,
                    itemCount: _messages.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final message = _messages[_messages.length - 1 - index];
                      return MessageBubble(
                        role: message.role,
                        content: message.content,
                        hidden: message.hidden,
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        FloatingComposer(
          controller: _controller,
          onSend: () {
            FocusScope.of(context).unfocus();
          },
        ),
      ],
    );
  }
}

class _MessageItem {
  const _MessageItem({
    required this.role,
    required this.content,
    this.hidden = false,
  });

  final String role;
  final String content;
  final bool hidden;
}
