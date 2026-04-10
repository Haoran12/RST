import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bridge/frb_api.dart' as frb;
import '../../../core/models/common.dart';
import '../../../core/providers/app_state.dart';
import '../../../core/providers/service_providers.dart';
import '../../../core/services/api_service.dart';
import '../../../core/services/chat_service.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/error_state_view.dart';
import '../../../shared/widgets/floating_composer.dart';
import '../../../shared/widgets/glass_panel_card.dart';
import '../../../shared/widgets/message_bubble.dart';
import '../../../shared/widgets/mode_chip.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/streaming_indicator.dart';

class ChatPage extends ConsumerStatefulWidget {
  const ChatPage({super.key});

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StartupChatRuntime? _runtime;
  frb.SessionConfig? _session;
  List<frb.MessageRecord> _messages = const <frb.MessageRecord>[];
  RoundTripMetadata? _lastRoundMetadata;
  String? _errorText;
  bool _isBootstrapping = true;
  bool _isSending = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
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
          _lastRoundMetadata = null;
        }
      });
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
      await ref
          .read(chatServiceProvider)
          .sendRound(
            SendRoundRequest(
              sessionId: roundSessionId,
              userInput: rawInput,
              apiConfig: runtime.apiConfig,
              presetConfig: runtime.presetConfig,
              maxContextMessages: runtime.maxContextMessages,
              sessionUserDescription: runtime.defaultUserDescription,
              sessionScene: runtime.defaultScene,
              sessionLores: runtime.defaultLores,
              onRoundPrepared: (metadata) {
                if (!mounted || _session?.sessionId != roundSessionId) {
                  return;
                }
                setState(() {
                  _lastRoundMetadata = metadata;
                });
              },
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
    } finally {
      if (mounted && _session?.sessionId == roundSessionId) {
        setState(() {
          _isSending = false;
        });
        await _reloadMessages(sessionId: roundSessionId);
      }
    }
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
    final runtime = _runtime;
    if (session == null || runtime == null) {
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

    final modeLabel = session.mode == frb.SessionMode.rst ? 'RST' : 'ST';
    final statusLabel = _isSending ? 'receiving' : 'idle';
    final statusColor = _isSending
        ? AppColors.accentSecondary
        : AppColors.success;

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: Column(
              children: [
                GlassPanelCard(
                  child: Row(
                    children: [
                      ModeChip(mode: modeLabel),
                      const SizedBox(width: 10),
                      StatusBadge(label: statusLabel, color: statusColor),
                      const Spacer(),
                      if (_isSending)
                        const StreamingIndicator(label: '接收响应中...')
                      else
                        const Text(
                          '等待发送',
                          style: TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                _RuntimeMetaCard(
                  session: session,
                  runtime: runtime,
                  roundMetadata: _lastRoundMetadata,
                ),
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
                            return _MessageWithMetadata(message: message);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
        FloatingComposer(
          controller: _controller,
          isSending: _isSending,
          onSend: _handleSendPressed,
        ),
      ],
    );
  }
}

class _RuntimeMetaCard extends StatelessWidget {
  const _RuntimeMetaCard({
    required this.session,
    required this.runtime,
    required this.roundMetadata,
  });

  final frb.SessionConfig session;
  final StartupChatRuntime runtime;
  final RoundTripMetadata? roundMetadata;

  @override
  Widget build(BuildContext context) {
    final provider = runtime.apiConfig.providerType == ProviderType.openai
        ? 'openai'
        : 'openai_compatible';

    return GlassPanelCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Session: ${session.sessionName} (${session.sessionId})'),
          const SizedBox(height: 4),
          Text('API: ${runtime.apiConfig.name} · $provider'),
          const SizedBox(height: 4),
          Text('Model: ${runtime.apiConfig.defaultModel}'),
          const SizedBox(height: 4),
          Text('Preset: ${runtime.presetConfig.name}'),
          if (roundMetadata != null) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, color: AppColors.borderSubtle),
            const SizedBox(height: 8),
            Text(
              'Prompt entries: ${roundMetadata!.prompt.entryOrder.join(' -> ')}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              'user_input: "${roundMetadata!.prompt.userInput}" (${roundMetadata!.prompt.userInputSource})',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              'request_url: ${roundMetadata!.requestUrl}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 2),
            Text(
              'request_body: ${roundMetadata!.requestBodyPreview}',
              maxLines: 5,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _MessageWithMetadata extends StatelessWidget {
  const _MessageWithMetadata({required this.message});

  final frb.MessageRecord message;

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
    final shortId = message.messageId.length >= 8
        ? message.messageId.substring(0, 8)
        : message.messageId;

    return Column(
      crossAxisAlignment: align,
      children: [
        MessageBubble(
          role: role,
          content: message.content,
          hidden: !message.visible,
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            'meta: $shortId · ${message.status.name} · $timestamp',
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
        ),
        if (message.errorMessage != null && message.errorMessage!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2, left: 6, right: 6),
            child: Text(
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
