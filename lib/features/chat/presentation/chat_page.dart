import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bridge/frb_api.dart' as frb;
import '../../../core/models/common.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/world_book_injection.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/utils/reasoning_markup.dart';
import '../../../shared/utils/responsive.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/floating_composer.dart';
import '../../../shared/widgets/app_notice.dart';
import '../../../shared/widgets/message_bubble.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _composerFocusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  late final StateController<ChatTopStatus> _chatTopStatusController;

  StartupChatRuntime? _runtime;
  frb.SessionConfig? _session;
  List<frb.MessageRecord> _messages = const <frb.MessageRecord>[];
  String? _errorText;
  bool _isBootstrapping = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _chatTopStatusController = ref.read(chatTopStatusProvider.notifier);
    _syncTopStatus();
    _bootstrap();
  }

  @override
  void dispose() {
    _chatTopStatusController.state = ChatTopStatus.calm;
    _controller.dispose();
    _composerFocusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  ChatTopStatus _resolveTopStatus() {
    if (_errorText != null) {
      return ChatTopStatus.error;
    }
    if (_isSending) {
      return ChatTopStatus.waiting;
    }
    return ChatTopStatus.calm;
  }

  void _syncTopStatus() {
    final next = _resolveTopStatus();
    if (_chatTopStatusController.state != next) {
      _chatTopStatusController.state = next;
    }
  }

  Future<void> _bootstrap({String? preferredSessionId}) async {
    final previousSessionId = _session?.sessionId;
    final targetSessionId =
        preferredSessionId ?? ref.read(currentSessionIdProvider);
    final shouldSwitchSession =
        previousSessionId != null && previousSessionId != targetSessionId;

    if (shouldSwitchSession && _isSending) {
      await ref.read(chatServiceProvider).stop(previousSessionId);
    }

    if (mounted) {
      setState(() {
        _isBootstrapping = true;
        if (shouldSwitchSession) {
          _session = null;
          _isSending = false;
          _messages = const <frb.MessageRecord>[];
        }
      });
      _syncTopStatus();
    }

    try {
      final apiService = ref.read(apiServiceProvider);
      final sessionService = ref.read(sessionServiceProvider);
      final rustBridge = ref.read(rustBridgeProvider);

      await apiService.ensureDefaults();
      List<frb.SessionSummary> sessions = await sessionService.listSessions();
      String? resolvedSessionId = targetSessionId;

      if (sessions.isEmpty) {
        final defaults = apiService.loadStartupRuntime();
        final created = await sessionService.createSession(
          sessionName: '默认会话',
          mode: SessionMode.rst,
          mainApiConfigId: defaults.apiConfig.apiId,
          presetId: defaults.presetConfig.presetId,
        );
        sessions = await sessionService.listSessions();
        resolvedSessionId = created.sessionId;
      }

      final fallbackSessionId = sessions.isNotEmpty
          ? sessions.first.sessionId
          : null;
      final exists =
          resolvedSessionId != null &&
          sessions.any((item) => item.sessionId == resolvedSessionId);
      resolvedSessionId = exists ? resolvedSessionId : fallbackSessionId;
      if (resolvedSessionId == null) {
        throw StateError('没有可用会话，且创建默认会话失败。');
      }

      final loaded = await sessionService.loadSession(resolvedSessionId);
      final sessionConfig = loaded.config;
      final runtime = await apiService.loadSessionRuntime(sessionConfig);
      final messages = await rustBridge.listMessages(
        sessionId: sessionConfig.sessionId,
      );

      final currentSessionId = ref.read(currentSessionIdProvider);
      if (currentSessionId != sessionConfig.sessionId) {
        ref.read(currentSessionIdProvider.notifier).state =
            sessionConfig.sessionId;
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _runtime = runtime;
        _session = sessionConfig;
        _messages = _sortMessages(messages);
        _errorText = null;
        _isBootstrapping = false;
        _isSending = false;
      });
      _syncTopStatus();
      _scrollToBottom(force: true);
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _errorText = error.toString();
        _isBootstrapping = false;
        _isSending = false;
      });
      _syncTopStatus();
    }
  }

  Future<void> _reloadMessages({String? sessionId}) async {
    final activeSessionId = sessionId ?? _session?.sessionId;
    if (activeSessionId == null) {
      return;
    }
    try {
      final messages = await ref
          .read(rustBridgeProvider)
          .listMessages(sessionId: activeSessionId);
      if (!mounted) {
        return;
      }
      if (_session?.sessionId != activeSessionId) {
        return;
      }
      setState(() {
        _messages = _sortMessages(messages);
      });
    } catch (_) {
      // Keep UI stable when background refresh fails.
    }
  }

  Future<void> _handleSendPressed() async {
    final session = _session;
    if (session == null) {
      return;
    }
    final roundSessionId = session.sessionId;

    if (_isSending) {
      await ref.read(chatServiceProvider).stop(roundSessionId);
      return;
    }

    final rawInput = _controller.text;
    final shouldClearComposer = rawInput.trim().isNotEmpty;
    FocusScope.of(context).unfocus();

    if (shouldClearComposer) {
      _controller.clear();
    }

    setState(() {
      _isSending = true;
      _errorText = null;
    });
    _syncTopStatus();

    try {
      final runtime = await ref
          .read(apiServiceProvider)
          .loadSessionRuntime(session);
      if (!mounted || _session?.sessionId != roundSessionId) {
        return;
      }
      setState(() {
        _runtime = runtime;
      });
      final sessionScopedData = ref.read(
        sessionRstDataProvider,
      )[roundSessionId];
      final sessionUserDescription =
          sessionScopedData?.userDescription ?? runtime.defaultUserDescription;
      final sessionScene = sessionScopedData?.scene ?? runtime.defaultScene;
      final baseLores = sessionScopedData?.lores ?? runtime.defaultLores;
      final injectedWorldBook = await _resolveWorldBookForInjection(session);
      final worldBookScanDepth = injectedWorldBook != null
          ? loadWorldBookScanDepth(injectedWorldBook)
          : 4;
      final loreInjection = session.mode == frb.SessionMode.st
          ? WorldBookInjection.buildStModeLore(
              sessionId: roundSessionId,
              userInput: rawInput,
              visibleMessages: _messages,
              baseLores: baseLores,
              userDescription: sessionUserDescription,
              scene: sessionScene,
              worldBook: injectedWorldBook,
              defaultScanDepth: worldBookScanDepth,
            )
          : StLoreInjectionResult(before: baseLores.trim(), after: '');
      await ref
          .read(chatServiceProvider)
          .sendRound(
            SendRoundRequest(
              sessionId: roundSessionId,
              userInput: rawInput,
              apiConfig: runtime.apiConfig,
              presetConfig: runtime.presetConfig,
              maxContextMessages: runtime.maxContextMessages,
              sessionUserDescription: sessionUserDescription,
              sessionScene: sessionScene,
              sessionLoreBefore: loreInjection.before,
              sessionLoreAfter: loreInjection.after,
              onMessageUpdated: (message) {
                if (!mounted || _session?.sessionId != roundSessionId) {
                  return;
                }
                setState(() {
                  _upsertMessage(message);
                });
                _scrollToBottom();
              },
            ),
          );
    } catch (error) {
      if (!mounted || _session?.sessionId != roundSessionId) {
        return;
      }
      setState(() {
        _errorText = error.toString();
      });
      _syncTopStatus();
    } finally {
      if (mounted && _session?.sessionId == roundSessionId) {
        setState(() {
          _isSending = false;
        });
        _syncTopStatus();
        await _reloadMessages(sessionId: roundSessionId);
      }
    }
  }

  ManagedOption? _resolveWorldBookOption(String? worldBookId) {
    if (worldBookId == null || worldBookId.trim().isEmpty) {
      return null;
    }
    final options = ref.read(worldBookOptionsProvider);
    for (final option in options) {
      if (option.id == worldBookId) {
        return option;
      }
    }
    return null;
  }

  Future<ManagedOption?> _resolveWorldBookForInjection(
    frb.SessionConfig session,
  ) async {
    final fallback = _resolveWorldBookOption(session.stWorldBookId);
    if (session.mode != frb.SessionMode.st) {
      return fallback;
    }

    final snapshotJson = await ref
        .read(apiServiceProvider)
        .loadSessionWorldBookSnapshotJson(sessionId: session.sessionId);
    if (snapshotJson == null || snapshotJson.trim().isEmpty) {
      return fallback;
    }

    return ManagedOption(
      id: session.stWorldBookId ?? 'snapshot-${session.sessionId}',
      name: fallback?.name ?? 'Session Snapshot',
      description: 'Static SillyTavern session snapshot',
      updatedAt: DateTime.now(),
      type: ManagedOptionType.worldBook,
      sections: <ManagedOptionSection>[
        ManagedOptionSection(
          title: 'Snapshot',
          description: '',
          fields: <ManagedOptionField>[
            ManagedOptionField(
              key: worldBookJsonFieldKey,
              label: 'worldbook_json',
              type: ManagedFieldType.multiline,
              value: snapshotJson,
            ),
          ],
        ),
      ],
    );
  }

  void _upsertMessage(frb.MessageRecord record) {
    final next = <frb.MessageRecord>[..._messages];
    final index = next.indexWhere((item) => item.messageId == record.messageId);
    if (index == -1) {
      next.add(record);
    } else {
      next[index] = record;
    }
    _messages = _sortMessages(next);
  }

  List<frb.MessageRecord> _sortMessages(List<frb.MessageRecord> source) {
    final next = [...source];
    next.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return next;
  }

  void _scrollToBottom({bool force = false}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }
      final position = _scrollController.position;
      final nearBottom = position.maxScrollExtent - position.pixels < 96;
      if (!force && !nearBottom) {
        return;
      }
      _scrollController.animateTo(
        position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _handleDeleteMessage(frb.MessageRecord message) async {
    final session = _session;
    if (session == null) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('删除消息'),
          content: const Text('确定删除这条消息？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed != true) {
      return;
    }
    try {
      await ref
          .read(rustBridgeProvider)
          .deleteMessages(
            sessionId: session.sessionId,
            messageIds: <String>[message.messageId],
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages = _messages
            .where((item) => item.messageId != message.messageId)
            .toList(growable: false);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: '删除失败: $error',
        tone: AppNoticeTone.error,
        category: 'chat_delete_failed',
      );
    }
  }

  Future<void> _handleCopyMessage(frb.MessageRecord message) async {
    final content = message.content.trim();
    if (content.isEmpty) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: content));
    if (!mounted) {
      return;
    }
    AppNotice.show(
      context,
      message: '已复制到剪贴板',
      tone: AppNoticeTone.success,
      category: 'chat_message_copied',
    );
  }

  Future<void> _handleToggleVisibility(frb.MessageRecord message) async {
    try {
      final updated = await ref
          .read(rustBridgeProvider)
          .setMessageVisibility(
            messageId: message.messageId,
            visible: !message.visible,
          );
      if (!mounted) {
        return;
      }
      setState(() {
        _upsertMessage(updated);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: '设置可见性失败: $error',
        tone: AppNoticeTone.error,
        category: 'chat_visibility_failed',
      );
    }
  }

  void _handleRewriteMessage(frb.MessageRecord message) {
    final source = ReasoningMarkup.stripReasoning(message.content).trim();
    if (source.isEmpty) {
      return;
    }
    final nextInput = message.role == frb.MessageRole.user
        ? source
        : '请改写以下内容，保持原意并优化表达：\n$source';
    _controller.value = TextEditingValue(
      text: nextInput,
      selection: TextSelection.collapsed(offset: nextInput.length),
    );
    _composerFocusNode.requestFocus();
    _scrollToBottom(force: true);
  }

  Future<void> _handleEditMessage(frb.MessageRecord message) async {
    final parsed = ReasoningMarkup.parse(message.content);
    final contentController = TextEditingController(text: parsed.content);
    final reasoningController = TextEditingController(text: parsed.reasoning);
    final dialogWidth = Responsive.isDesktop(context) ? 640.0 : 480.0;
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('编辑消息'),
            content: SizedBox(
              width: dialogWidth,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: contentController,
                    maxLines: 8,
                    minLines: 3,
                    decoration: const InputDecoration(labelText: '内容'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: reasoningController,
                    maxLines: 8,
                    minLines: 2,
                    decoration: const InputDecoration(labelText: '思考'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('保存'),
              ),
            ],
          );
        },
      );
      if (approved != true) {
        return;
      }
      final merged = ReasoningMarkup.compose(
        content: contentController.text,
        reasoning: reasoningController.text,
      );
      final updated = await ref
          .read(rustBridgeProvider)
          .updateMessageContent(messageId: message.messageId, content: merged);
      if (!mounted) {
        return;
      }
      setState(() {
        _upsertMessage(updated);
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      AppNotice.show(
        context,
        message: '编辑失败: $error',
        tone: AppNoticeTone.error,
        category: 'chat_edit_failed',
      );
    } finally {
      contentController.dispose();
      reasoningController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(currentSessionIdProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      unawaited(_bootstrap(preferredSessionId: next));
    });
    ref.listen<int>(workspaceReloadTickProvider, (previous, next) {
      if (previous == next) {
        return;
      }
      unawaited(
        _bootstrap(preferredSessionId: ref.read(currentSessionIdProvider)),
      );
    });

    if (_isBootstrapping) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorText != null && _session == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: ErrorStateView(
          message: _errorText!,
          onRetry: () {
            _bootstrap();
          },
        ),
      );
    }

    final session = _session;
    if (session == null || _runtime == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: EmptyStateView(
          title: '会话未就绪',
          description: '初始化会话失败，请重试。',
          actionLabel: '重试',
          onAction: () {
            _bootstrap();
          },
        ),
      );
    }

    final bubbleAppearance = _resolveBubbleAppearance(session.sessionId);
    final floorByMessageId = _buildFloorByMessageId(_messages);

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Column(
              children: [
                if (_errorText != null) ...[
                  const SizedBox(height: 10),
                  ErrorStateView(
                    message: _errorText!,
                    onRetry: () {
                      _handleSendPressed();
                    },
                  ),
                ],
                const SizedBox(height: 12),
                Expanded(
                  child: _messages.isEmpty
                      ? const Center(
                          child: Text(
                            '还没有消息，输入后发送开始对话。',
                            style: TextStyle(color: AppColors.textMuted),
                          ),
                        )
                      : ListView.separated(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final hasContent = message.content
                                .trim()
                                .isNotEmpty;
                            final canDelete =
                                message.status != frb.MessageStatus.pending &&
                                message.status != frb.MessageStatus.streaming;
                            final canEdit =
                                message.status != frb.MessageStatus.pending &&
                                message.status != frb.MessageStatus.streaming;
                            return _MessageWithMetadata(
                              message: message,
                              floorNo: floorByMessageId[message.messageId],
                              appearance: bubbleAppearance,
                              onToggleVisibility: _handleToggleVisibility,
                              onDelete: canDelete ? _handleDeleteMessage : null,
                              onCopy: hasContent ? _handleCopyMessage : null,
                              onEdit: canEdit ? _handleEditMessage : null,
                              onRewrite: hasContent
                                  ? _handleRewriteMessage
                                  : null,
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
          focusNode: _composerFocusNode,
          isSending: _isSending,
          onSend: _handleSendPressed,
        ),
      ],
    );
  }

  MessageBubbleAppearance _resolveBubbleAppearance(String sessionId) {
    final appearanceBySession = ref.watch(sessionAppearanceProvider);
    final appearanceOptions = ref.watch(appearanceOptionsProvider);
    final selectedAppearanceId = appearanceBySession[sessionId];

    ManagedOption? selected;
    if (selectedAppearanceId != null && selectedAppearanceId.isNotEmpty) {
      for (final option in appearanceOptions) {
        if (option.id == selectedAppearanceId) {
          selected = option;
          break;
        }
      }
    }
    selected ??= appearanceOptions.isNotEmpty ? appearanceOptions.first : null;

    final fontScale = _readDoubleField(
      selected,
      'font_scale',
      1.0,
    ).clamp(0.8, 1.6);
    final bubbleOpacity = _readDoubleField(
      selected,
      'message_bubble_opacity',
      1.0,
    ).clamp(0.0, 1.0);

    return MessageBubbleAppearance(
      paragraphColor: _readColorField(
        selected,
        'markdown_paragraph_color',
        AppColors.textStrong,
      ),
      headingColor: _readColorField(
        selected,
        'markdown_heading_color',
        AppColors.textStrong,
      ),
      italicColor: _readColorField(
        selected,
        'markdown_italic_color',
        AppColors.textSecondary,
      ),
      boldColor: _readColorField(
        selected,
        'markdown_bold_color',
        AppColors.textStrong,
      ),
      quotedColor: _readColorField(
        selected,
        'markdown_quoted_color',
        AppColors.warning,
      ),
      fontScale: fontScale,
      bubbleOpacity: bubbleOpacity,
    );
  }

  Map<String, int> _buildFloorByMessageId(List<frb.MessageRecord> messages) {
    final floors = <String, int>{};
    var fallbackFloor = 0;
    for (final message in messages) {
      if (message.role != frb.MessageRole.user &&
          message.role != frb.MessageRole.assistant) {
        continue;
      }
      final persistedFloor = message.floorNo?.toInt();
      if (persistedFloor != null) {
        floors[message.messageId] = persistedFloor;
        fallbackFloor = persistedFloor + 1;
      } else {
        floors[message.messageId] = fallbackFloor;
        fallbackFloor += 1;
      }
    }
    return floors;
  }

  double _readDoubleField(ManagedOption? option, String key, double fallback) {
    if (option == null) {
      return fallback;
    }
    final value = option.fieldValue(key);
    if (value is num) {
      return value.toDouble();
    }
    if (value is String) {
      final normalized = value.trim().replaceAll(',', '.');
      return double.tryParse(normalized) ?? fallback;
    }
    return fallback;
  }

  Color _readColorField(ManagedOption? option, String key, Color fallback) {
    if (option == null) {
      return fallback;
    }
    final value = option.fieldValue(key);
    if (value is! String) {
      return fallback;
    }
    return _parseHexColor(value, fallback);
  }

  Color _parseHexColor(String raw, Color fallback) {
    final normalized = raw.trim();
    if (normalized.isEmpty) {
      return fallback;
    }
    var hex = normalized.startsWith('#') ? normalized.substring(1) : normalized;
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    final parsed = int.tryParse(hex, radix: 16);
    if (parsed == null) {
      return fallback;
    }
    return Color(parsed);
  }
}

class _MessageWithMetadata extends StatelessWidget {
  const _MessageWithMetadata({
    required this.message,
    required this.floorNo,
    required this.appearance,
    required this.onToggleVisibility,
    this.onDelete,
    this.onCopy,
    this.onEdit,
    this.onRewrite,
  });

  final frb.MessageRecord message;
  final int? floorNo;
  final MessageBubbleAppearance appearance;
  final void Function(frb.MessageRecord message) onToggleVisibility;
  final void Function(frb.MessageRecord message)? onDelete;
  final void Function(frb.MessageRecord message)? onCopy;
  final void Function(frb.MessageRecord message)? onEdit;
  final void Function(frb.MessageRecord message)? onRewrite;

  @override
  Widget build(BuildContext context) {
    final role = switch (message.role) {
      frb.MessageRole.system => 'system',
      frb.MessageRole.user => 'user',
      frb.MessageRole.assistant => 'assistant',
    };
    final align = role == 'user'
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final timestamp = _formatTime(message.updatedAt);
    final headerMeta = floorNo == null ? timestamp : '$floorNo# · $timestamp';

    return Column(
      crossAxisAlignment: align,
      children: [
        MessageBubble(
          messageId: message.messageId,
          role: role,
          content: message.content,
          headerMeta: headerMeta,
          appearance: appearance,
          hidden: !message.visible,
          onToggleVisibility: () => onToggleVisibility(message),
          onDelete: onDelete == null ? null : () => onDelete!(message),
          onCopy: onCopy == null ? null : () => onCopy!(message),
          onEdit: onEdit == null ? null : () => onEdit!(message),
          onRewrite: onRewrite == null ? null : () => onRewrite!(message),
        ),
        if (message.errorMessage != null && message.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 6, right: 6),
            child: SelectableText(
              message.errorMessage!,
              style: const TextStyle(fontSize: 11, color: AppColors.error),
            ),
          ),
      ],
    );
  }

  String _formatTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$hour:$minute:$second';
  }
}
