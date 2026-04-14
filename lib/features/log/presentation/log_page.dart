import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/bridge/frb_api.dart' as frb;
import '../../../core/providers/app_state.dart';
import '../../../core/providers/service_providers.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/glass_panel_card.dart';
import '../../../shared/widgets/status_badge.dart';

class LogPage extends ConsumerStatefulWidget {
  const LogPage({super.key});

  @override
  ConsumerState<LogPage> createState() => _LogPageState();
}

class _LogPageState extends ConsumerState<LogPage> {
  late Future<List<frb.RequestLogSummary>> _logsFuture;

  @override
  void initState() {
    super.initState();
    _logsFuture = _loadLogs();
  }

  Future<List<frb.RequestLogSummary>> _loadLogs() {
    return ref.read(logServiceProvider).loadRecentLogs(limit: 100);
  }

  void _reload() {
    setState(() {
      _logsFuture = _loadLogs();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      child: FutureBuilder<List<frb.RequestLogSummary>>(
        future: _logsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return EmptyStateView(
              title: '日志加载失败',
              description: '${snapshot.error}',
              actionLabel: '重试',
              onAction: _reload,
            );
          }

          final logs = snapshot.data ?? const <frb.RequestLogSummary>[];
          if (logs.isEmpty) {
            return EmptyStateView(
              title: '暂无日志',
              description: '发送一轮消息后会出现请求摘要。',
              actionLabel: '去聊天',
              onAction: () {
                ref.read(appTabProvider.notifier).state = AppTab.chat;
              },
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: logs.length,
              separatorBuilder: (context, index) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final item = logs[index];
                final isError = item.status == frb.RequestLogStatus.error;
                final durationLabel = item.durationMs == null
                    ? '-'
                    : '${item.durationMs}ms';
                return InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _openDetail(item.logId),
                  child: GlassPanelCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.model,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${item.provider} · ${_formatTime(item.requestTime)}',
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text('duration: $durationLabel'),
                            ],
                          ),
                        ),
                        StatusBadge(
                          label: item.status.name,
                          color: isError ? AppColors.error : AppColors.success,
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  String _formatTime(String raw) {
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return raw;
    }
    final local = parsed.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$month-$day $hour:$minute:$second';
  }

  Future<void> _openDetail(String logId) async {
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: _LogDetailSheet(logId: logId),
        );
      },
    );
  }
}

class _LogDetailSheet extends ConsumerWidget {
  const _LogDetailSheet({required this.logId});

  final String logId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<frb.RequestLog>(
      future: ref.read(logServiceProvider).getLogDetail(logId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text('加载详情失败: ${snapshot.error}'),
          );
        }

        final log = snapshot.data;
        if (log == null) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Text('日志不存在'),
          );
        }
        final requestPreviewText = _formatPreviewForDisplay(
          log.requestPreviewJson,
        );
        final responsePreviewDecoded = _tryDecodePreview(
          log.responsePreviewJson,
        );
        final rawResponsePreviewText = _formatRawResponseForDisplay(
          original: log.responsePreviewJson,
          decoded: responsePreviewDecoded,
        );
        final normalizedResponseText = _extractNormalizedResponseForDisplay(
          responsePreviewDecoded,
        );

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ListView(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${log.model} · ${log.status.name}',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _DetailRow(label: 'session', value: log.sessionId),
              _DetailRow(label: 'provider', value: log.provider),
              _DetailRow(label: 'request', value: log.requestTime),
              _DetailRow(label: 'response', value: log.responseTime ?? '-'),
              _DetailRow(
                label: 'duration',
                value: log.durationMs == null ? '-' : '${log.durationMs}ms',
              ),
              _DetailRow(
                label: 'tokens',
                value:
                    'prompt=${log.promptTokens ?? '-'}, completion=${log.completionTokens ?? '-'}, total=${log.totalTokens ?? '-'}',
              ),
              _DetailRow(label: 'stop_reason', value: log.stopReason ?? '-'),
              _DetailRow(label: 'redacted', value: '${log.redacted}'),
              _DetailRow(
                label: 'payload_truncated',
                value: '${log.payloadTruncated}',
              ),
              const SizedBox(height: 12),
              _CollapsibleLogBlock(
                title: '原始请求 (Redacted)',
                content: requestPreviewText,
              ),
              const SizedBox(height: 12),
              _CollapsibleLogBlock(
                title: '原始响应 (Redacted)',
                content: rawResponsePreviewText,
              ),
              const SizedBox(height: 12),
              _CollapsibleLogBlock(
                title: '整理后的完整响应',
                content: normalizedResponseText,
              ),
            ],
          ),
        );
      },
    );
  }

  static Object? _tryDecodePreview(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return null;
    }
    try {
      return jsonDecode(raw);
    } catch (_) {
      return null;
    }
  }

  static String _formatPreviewForDisplay(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return '(empty)';
    }
    final decoded = _tryDecodePreview(raw);
    if (decoded == null) {
      return raw;
    }
    return const JsonEncoder.withIndent('  ').convert(decoded);
  }

  static String _formatRawResponseForDisplay({
    required String? original,
    required Object? decoded,
  }) {
    if (decoded is! Map) {
      return _formatPreviewForDisplay(original);
    }
    final cloned = <String, Object?>{};
    decoded.forEach((key, value) {
      cloned['$key'] = value;
    });
    cloned.remove('normalized_response');
    if (cloned.isEmpty) {
      return '(empty)';
    }
    return const JsonEncoder.withIndent('  ').convert(cloned);
  }

  static String _extractNormalizedResponseForDisplay(Object? decoded) {
    if (decoded is Map) {
      final value = decoded['normalized_response'];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
      if (value != null) {
        final fallback = '$value'.trim();
        if (fallback.isNotEmpty) {
          return fallback;
        }
      }
    }
    return '(empty)';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 420) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.textMuted)),
                const SizedBox(height: 2),
                SelectableText(value),
              ],
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 120,
                child: Text(
                  label,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
              Expanded(child: SelectableText(value)),
            ],
          ),
        );
      },
    );
  }
}

class _CollapsibleLogBlock extends StatelessWidget {
  const _CollapsibleLogBlock({required this.title, required this.content});

  final String title;
  final String content;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
          title: Text(title, style: Theme.of(context).textTheme.titleSmall),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: SelectableText(
                content,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
