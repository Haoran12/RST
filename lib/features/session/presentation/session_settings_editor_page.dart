import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/app_state.dart';
import '../../../shared/theme/app_colors.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/glass_panel_card.dart';

class SessionSettingsOptionEntry {
  const SessionSettingsOptionEntry({required this.id, required this.label});

  final String id;
  final String label;
}

class SessionSettingsDraft {
  const SessionSettingsDraft({
    required this.sessionName,
    required this.userDescription,
    required this.worldDescription,
    required this.characterDescription,
    required this.schedulerMode,
    required this.apiConfigId,
    required this.presetId,
    this.worldBookId,
    required this.appearanceId,
    required this.backgroundImagePath,
  });

  final String sessionName;
  final String userDescription;
  final String worldDescription;
  final String characterDescription;
  final SchedulerMode schedulerMode;
  final String apiConfigId;
  final String presetId;
  final String? worldBookId;
  final String appearanceId;
  final String backgroundImagePath;

  SessionSettingsDraft copyWith({
    String? sessionName,
    String? userDescription,
    String? worldDescription,
    String? characterDescription,
    SchedulerMode? schedulerMode,
    String? apiConfigId,
    String? presetId,
    String? worldBookId,
    bool replaceWorldBookId = false,
    String? appearanceId,
    String? backgroundImagePath,
  }) {
    return SessionSettingsDraft(
      sessionName: sessionName ?? this.sessionName,
      userDescription: userDescription ?? this.userDescription,
      worldDescription: worldDescription ?? this.worldDescription,
      characterDescription: characterDescription ?? this.characterDescription,
      schedulerMode: schedulerMode ?? this.schedulerMode,
      apiConfigId: apiConfigId ?? this.apiConfigId,
      presetId: presetId ?? this.presetId,
      worldBookId: replaceWorldBookId
          ? worldBookId
          : (worldBookId ?? this.worldBookId),
      appearanceId: appearanceId ?? this.appearanceId,
      backgroundImagePath: backgroundImagePath ?? this.backgroundImagePath,
    );
  }

  bool sameAs(SessionSettingsDraft other) {
    return sessionName == other.sessionName &&
        userDescription == other.userDescription &&
        worldDescription == other.worldDescription &&
        characterDescription == other.characterDescription &&
        schedulerMode == other.schedulerMode &&
        apiConfigId == other.apiConfigId &&
        presetId == other.presetId &&
        worldBookId == other.worldBookId &&
        appearanceId == other.appearanceId &&
        backgroundImagePath == other.backgroundImagePath;
  }
}

class SessionSettingsEditorPage extends ConsumerStatefulWidget {
  const SessionSettingsEditorPage({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.initialDraft,
    required this.apiOptions,
    required this.presetOptions,
    required this.worldBookOptions,
    required this.appearanceOptions,
    this.onSubmit,
    this.popAfterSubmit = true,
    this.enableDetailJump = false,
  });

  final String title;
  final String actionLabel;
  final SessionSettingsDraft initialDraft;
  final List<SessionSettingsOptionEntry> apiOptions;
  final List<SessionSettingsOptionEntry> presetOptions;
  final List<SessionSettingsOptionEntry> worldBookOptions;
  final List<SessionSettingsOptionEntry> appearanceOptions;
  final Future<void> Function(SessionSettingsDraft draft)? onSubmit;
  final bool popAfterSubmit;
  final bool enableDetailJump;

  @override
  ConsumerState<SessionSettingsEditorPage> createState() =>
      _SessionSettingsEditorPageState();
}

class _SessionSettingsEditorPageState
    extends ConsumerState<SessionSettingsEditorPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  late SessionSettingsDraft _draft;
  late SessionSettingsDraft _baseline;
  bool _submitting = false;
  String? _submitError;

  @override
  void initState() {
    super.initState();
    _draft = widget.initialDraft;
    _baseline = widget.initialDraft;
  }

  @override
  Widget build(BuildContext context) {
    final apiOptions = _ensureOption(
      _draft.apiConfigId,
      widget.apiOptions,
      allowNull: false,
    );
    final presetOptions = _ensureOption(
      _draft.presetId,
      widget.presetOptions,
      allowNull: false,
    );
    final worldBookOptions = _ensureOption(
      _draft.worldBookId,
      widget.worldBookOptions,
      allowNull: true,
    );
    final appearanceOptions = _ensureOption(
      _draft.appearanceId,
      widget.appearanceOptions,
      allowNull: false,
    );

    return PopScope<SessionSettingsDraft>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldClose = await _handleAttemptDismiss();
        if (!mounted || !shouldClose) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: _SessionSettingsNavDrawer(
          currentTab: ref.watch(appTabProvider),
          onSelect: _handleDrawerTabSelect,
        ),
        appBar: AppBar(
          leading: IconButton(
            tooltip: '打开导航菜单',
            onPressed: () {
              _scaffoldKey.currentState?.openDrawer();
            },
            icon: const Icon(Icons.menu_rounded),
          ),
          title: Text(widget.title),
          actions: [
            TextButton(
              onPressed: _submitting ? null : _submit,
              child: Text(_submitting ? '保存中...' : widget.actionLabel),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            children: [
              _ActionCard(
                title: '基本配置',
                subtitle: _buildBasicSummary(),
                onTap: _openBasicConfig,
              ),
              const SizedBox(height: 10),
              _TavoPickerCard(
                title: '选用的API配置',
                valueLabel: _resolveOptionLabel(
                  selectedId: _draft.apiConfigId,
                  options: apiOptions,
                ),
                detailLabel: _draft.apiConfigId,
                onTap: () => _openApiConfigPicker(apiOptions),
                onEdit: widget.enableDetailJump
                    ? () => _jumpToDetailTab(AppTab.apiConfig)
                    : null,
              ),
              const SizedBox(height: 10),
              _TavoPickerCard(
                title: '选用的预设',
                valueLabel: _resolveOptionLabel(
                  selectedId: _draft.presetId,
                  options: presetOptions,
                ),
                detailLabel: _draft.presetId,
                onTap: () => _openPresetPicker(presetOptions),
                onEdit: widget.enableDetailJump
                    ? () => _jumpToDetailTab(AppTab.preset)
                    : null,
              ),
              const SizedBox(height: 10),
              _TavoPickerCard(
                title: '调度器模式',
                valueLabel: _schedulerLabel(_draft.schedulerMode),
                detailLabel: _schedulerDetail(_draft.schedulerMode),
                onTap: _openSchedulerPicker,
                onEdit: widget.enableDetailJump
                    ? () => _jumpToDetailTab(AppTab.sessionManagement)
                    : null,
              ),
              const SizedBox(height: 10),
              _TavoPickerCard(
                title: '对应的世界书',
                valueLabel: _resolveOptionLabel(
                  selectedId: _draft.worldBookId,
                  options: worldBookOptions,
                  emptyLabel: '不绑定',
                ),
                detailLabel: _buildWorldBookDetail(),
                onTap: () => _openWorldBookPicker(worldBookOptions),
                onEdit: () => _openWorldBook(worldBookOptions),
              ),
              const SizedBox(height: 10),
              _TavoPickerCard(
                title: '外观设置',
                valueLabel: _resolveOptionLabel(
                  selectedId: _draft.appearanceId,
                  options: appearanceOptions,
                ),
                detailLabel: _buildAppearanceDetail(),
                onTap: () => _openAppearancePicker(appearanceOptions),
                onEdit: () => _openAppearance(appearanceOptions),
              ),
              if (_submitError != null) ...[
                const SizedBox(height: 10),
                Text(
                  _submitError!,
                  style: const TextStyle(color: AppColors.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _submitting ? null : _submit,
                child: Text(_submitting ? '保存中...' : widget.actionLabel),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleDrawerTabSelect(AppTab tab) async {
    Navigator.of(context).pop();
    final shouldClose = await _handleAttemptDismiss();
    if (!mounted || !shouldClose) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    ref.read(appTabProvider.notifier).state = tab;
  }

  List<SessionSettingsOptionEntry> _ensureOption(
    String? selectedId,
    List<SessionSettingsOptionEntry> source, {
    required bool allowNull,
  }) {
    final entries = source.toList(growable: true);
    if (allowNull && (selectedId == null || selectedId.isEmpty)) {
      return entries;
    }
    if (selectedId == null || selectedId.isEmpty) {
      return entries;
    }
    if (entries.any((item) => item.id == selectedId)) {
      return entries;
    }
    return <SessionSettingsOptionEntry>[
      SessionSettingsOptionEntry(id: selectedId, label: '$selectedId (未在列表)'),
      ...entries,
    ];
  }

  Future<void> _jumpToDetailTab(AppTab tab) async {
    final shouldClose = await _handleAttemptDismiss();
    if (!mounted || !shouldClose) {
      return;
    }
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
    ref.read(appTabProvider.notifier).state = tab;
  }

  String _resolveOptionLabel({
    required String? selectedId,
    required List<SessionSettingsOptionEntry> options,
    String emptyLabel = '未设置',
  }) {
    if (selectedId == null || selectedId.isEmpty) {
      return emptyLabel;
    }
    for (final option in options) {
      if (option.id == selectedId) {
        return option.label;
      }
    }
    return '$selectedId (未在列表)';
  }

  String _schedulerLabel(SchedulerMode mode) {
    return switch (mode) {
      SchedulerMode.direct => 'direct',
      SchedulerMode.rst => 'RST',
      SchedulerMode.agent => 'Agent',
    };
  }

  String _schedulerDetail(SchedulerMode mode) {
    return switch (mode) {
      SchedulerMode.direct => '直接拼接上下文，路径最短',
      SchedulerMode.rst => 'RST 调度，含结构化注入',
      SchedulerMode.agent => 'Agent 调度，适合复杂流程',
    };
  }

  String _buildWorldBookDetail() {
    final worldReady = _draft.worldDescription.trim().isNotEmpty;
    final characterReady = _draft.characterDescription.trim().isNotEmpty;
    final worldState = worldReady ? '已填写' : '未填写';
    final characterState = characterReady ? '已填写' : '未填写';
    return '世界描述：$worldState · 人物设定：$characterState';
  }

  String _buildAppearanceDetail() {
    return _draft.backgroundImagePath.trim().isEmpty ? '背景：默认' : '背景：已设置';
  }

  Future<void> _openApiConfigPicker(
    List<SessionSettingsOptionEntry> options,
  ) async {
    final selected = await _showPickerDrawer<String>(
      title: '选择 API 配置',
      currentValue: _draft.apiConfigId,
      options: options
          .map(
            (item) => _PickerOption<String>(
              value: item.id,
              label: item.label,
              detail: item.id,
            ),
          )
          .toList(growable: false),
      onEditOption: widget.enableDetailJump
          ? (option) => _jumpToDetailTab(AppTab.apiConfig)
          : null,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(apiConfigId: selected.value);
    });
  }

  Future<void> _openPresetPicker(
    List<SessionSettingsOptionEntry> options,
  ) async {
    final selected = await _showPickerDrawer<String>(
      title: '选择预设',
      currentValue: _draft.presetId,
      options: options
          .map(
            (item) => _PickerOption<String>(
              value: item.id,
              label: item.label,
              detail: item.id,
            ),
          )
          .toList(growable: false),
      onEditOption: widget.enableDetailJump
          ? (option) => _jumpToDetailTab(AppTab.preset)
          : null,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(presetId: selected.value);
    });
  }

  Future<void> _openSchedulerPicker() async {
    final options = const <_PickerOption<SchedulerMode>>[
      _PickerOption<SchedulerMode>(
        value: SchedulerMode.direct,
        label: 'direct',
        detail: '直接拼接上下文',
      ),
      _PickerOption<SchedulerMode>(
        value: SchedulerMode.rst,
        label: 'RST',
        detail: '结构化调度',
      ),
      _PickerOption<SchedulerMode>(
        value: SchedulerMode.agent,
        label: 'Agent',
        detail: '多步骤 Agent 模式',
      ),
    ];
    final selected = await _showPickerDrawer<SchedulerMode>(
      title: '选择调度器模式',
      currentValue: _draft.schedulerMode,
      options: options,
      onEditOption: widget.enableDetailJump
          ? (option) => _jumpToDetailTab(AppTab.sessionManagement)
          : null,
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(schedulerMode: selected.value);
    });
  }

  Future<void> _openWorldBookPicker(
    List<SessionSettingsOptionEntry> options,
  ) async {
    final selected = await _showPickerDrawer<String?>(
      title: '选择世界书',
      currentValue: _draft.worldBookId,
      options: <_PickerOption<String?>>[
        const _PickerOption<String?>(
          value: null,
          label: '不绑定',
          detail: '本会话不注入世界书',
        ),
        ...options.map(
          (item) => _PickerOption<String?>(
            value: item.id,
            label: item.label,
            detail: item.id,
          ),
        ),
      ],
      onEditOption: (option) => _openWorldBook(options),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(
        worldBookId: selected.value,
        replaceWorldBookId: true,
      );
    });
  }

  Future<void> _openAppearancePicker(
    List<SessionSettingsOptionEntry> options,
  ) async {
    final selected = await _showPickerDrawer<String>(
      title: '选择外观',
      currentValue: _draft.appearanceId,
      options: options
          .map(
            (item) => _PickerOption<String>(
              value: item.id,
              label: item.label,
              detail: item.id,
            ),
          )
          .toList(growable: false),
      onEditOption: (option) => _openAppearance(options),
    );
    if (!mounted || selected == null) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(appearanceId: selected.value);
    });
  }

  Future<_PickerSelection<T>?> _showPickerDrawer<T>({
    required String title,
    required T currentValue,
    required List<_PickerOption<T>> options,
    Future<void> Function(_PickerOption<T> option)? onEditOption,
  }) async {
    final result = await showModalBottomSheet<_PickerSelection<T>>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: AppColors.backgroundElevated,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => FractionallySizedBox(
        heightFactor: 0.72,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.borderStrong,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final option = options[index];
                    final selected = option.value == currentValue;

                    return GlassPanelCard(
                      padding: EdgeInsets.zero,
                      borderColor: selected
                          ? AppColors.borderStrong
                          : AppColors.borderSubtle,
                      backgroundColor: selected
                          ? AppColors.surfaceActive.withValues(alpha: 0.88)
                          : null,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          Navigator.of(
                            sheetContext,
                          ).pop(_PickerSelection<T>(option.value));
                        },
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(14, 11, 8, 11),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      option.label,
                                      style: Theme.of(
                                        context,
                                      ).textTheme.titleMedium,
                                    ),
                                    if (option.detail != null) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        option.detail!,
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall
                                            ?.copyWith(
                                              color: AppColors.textSecondary,
                                            ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              if (onEditOption != null)
                                IconButton(
                                  tooltip: '编辑',
                                  onPressed: () async {
                                    Navigator.of(sheetContext).pop();
                                    await onEditOption(option);
                                  },
                                  icon: const Icon(Icons.edit_outlined),
                                ),
                              if (selected)
                                const Padding(
                                  padding: EdgeInsets.only(right: 8),
                                  child: Icon(
                                    Icons.check_circle_rounded,
                                    color: AppColors.accentSecondary,
                                  ),
                                )
                              else
                                const SizedBox(width: 8),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return result;
  }

  Future<void> _openBasicConfig() async {
    final result = await Navigator.of(context).push<_BasicConfigResult>(
      MaterialPageRoute<_BasicConfigResult>(
        fullscreenDialog: true,
        builder: (context) => _BasicConfigPage(
          initialName: _draft.sessionName,
          initialUserDescription: _draft.userDescription,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(
        sessionName: result.sessionName,
        userDescription: result.userDescription,
      );
    });
  }

  Future<void> _openWorldBook(
    List<SessionSettingsOptionEntry> worldBookOptions,
  ) async {
    final result = await Navigator.of(context).push<_WorldBookEditorResult>(
      MaterialPageRoute<_WorldBookEditorResult>(
        fullscreenDialog: true,
        builder: (context) => _WorldBookEditorPage(
          options: worldBookOptions,
          initialWorldBookId: _draft.worldBookId,
          initialWorldDescription: _draft.worldDescription,
          initialCharacterDescription: _draft.characterDescription,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(
        worldBookId: result.worldBookId,
        replaceWorldBookId: true,
        worldDescription: result.worldDescription,
        characterDescription: result.characterDescription,
      );
    });
  }

  Future<void> _openAppearance(
    List<SessionSettingsOptionEntry> appearanceOptions,
  ) async {
    final result = await Navigator.of(context).push<_AppearanceEditorResult>(
      MaterialPageRoute<_AppearanceEditorResult>(
        fullscreenDialog: true,
        builder: (context) => _AppearanceEditorPage(
          options: appearanceOptions,
          initialAppearanceId: _draft.appearanceId,
          initialBackgroundPath: _draft.backgroundImagePath,
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _draft = _draft.copyWith(
        appearanceId: result.appearanceId,
        backgroundImagePath: result.backgroundImagePath,
      );
    });
  }

  String _buildBasicSummary() {
    final name = _draft.sessionName.trim().isEmpty
        ? '未命名会话'
        : _draft.sessionName;
    final userDescription = _draft.userDescription.trim();
    if (userDescription.isEmpty) {
      return '$name\n用户描述：未填写';
    }
    return '$name\n用户描述：${_shortPreview(userDescription)}';
  }

  String _shortPreview(String text) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= 40) {
      return normalized;
    }
    return '${normalized.substring(0, 40)}...';
  }

  Future<void> _submit() async {
    final normalizedName = _draft.sessionName.trim();
    if (normalizedName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会话名称不能为空')));
      return;
    }

    final normalizedDraft = _draft.copyWith(sessionName: normalizedName);
    if (widget.onSubmit == null) {
      Navigator.of(context).pop(normalizedDraft);
      return;
    }

    setState(() {
      _submitting = true;
      _submitError = null;
      _draft = normalizedDraft;
    });
    try {
      await widget.onSubmit!(normalizedDraft);
      if (!mounted) {
        return;
      }
      setState(() {
        _baseline = normalizedDraft;
      });
      if (widget.popAfterSubmit) {
        Navigator.of(context).pop(normalizedDraft);
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会话设置已保存')));
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _submitError = '$error';
      });
    } finally {
      if (mounted) {
        setState(() {
          _submitting = false;
        });
      }
    }
  }

  Future<bool> _handleAttemptDismiss() async {
    if (_draft.sameAs(_baseline)) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('你已经修改了会话设置，现在返回会丢失本次填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _PickerOption<T> {
  const _PickerOption({required this.value, required this.label, this.detail});

  final T value;
  final String label;
  final String? detail;
}

class _PickerSelection<T> {
  const _PickerSelection(this.value);

  final T value;
}

class _TavoPickerCard extends StatelessWidget {
  const _TavoPickerCard({
    required this.title,
    required this.valueLabel,
    required this.onTap,
    this.detailLabel,
    this.onEdit,
  });

  final String title;
  final String valueLabel;
  final String? detailLabel;
  final VoidCallback onTap;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    return GlassPanelCard(
      padding: EdgeInsets.zero,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      valueLabel,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.textStrong,
                      ),
                    ),
                    if (detailLabel != null && detailLabel!.trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          detailLabel!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: AppColors.textSecondary,
                                height: 1.2,
                              ),
                        ),
                      ),
                  ],
                ),
              ),
              if (onEdit != null)
                IconButton(
                  tooltip: '编辑',
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined),
                ),
              const Icon(Icons.expand_more_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionSettingsNavDrawer extends StatelessWidget {
  const _SessionSettingsNavDrawer({
    required this.currentTab,
    required this.onSelect,
  });

  final AppTab currentTab;
  final ValueChanged<AppTab> onSelect;

  static const _items = <_SessionNavItem>[
    _SessionNavItem(AppTab.chat, '聊天', Icons.forum_outlined),
    _SessionNavItem(
      AppTab.sessionManagement,
      '会话管理',
      Icons.chat_bubble_outline_rounded,
    ),
    _SessionNavItem(AppTab.worldBook, '世界书', Icons.menu_book_outlined),
    _SessionNavItem(AppTab.preset, '预设', Icons.auto_awesome_motion_outlined),
    _SessionNavItem(AppTab.apiConfig, 'API配置', Icons.cloud_sync_outlined),
    _SessionNavItem(AppTab.appearance, '外观', Icons.palette_outlined),
    _SessionNavItem(AppTab.log, '日志', Icons.receipt_long_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.backgroundElevated,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              GlassPanelCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                child: Text(
                  'RST',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final item = _items[index];
                    return _SessionDrawerItemCard(
                      label: item.label,
                      icon: item.icon,
                      selected: item.tab == currentTab,
                      onTap: () => onSelect(item.tab),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionDrawerItemCard extends StatelessWidget {
  const _SessionDrawerItemCard({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final borderColor = selected
        ? AppColors.borderStrong
        : AppColors.borderSubtle;
    final background = selected
        ? AppColors.surfaceOverlay.withValues(alpha: 0.72)
        : AppColors.surfaceCard.withValues(alpha: 0.84);
    final iconColor = selected
        ? AppColors.accentPrimary
        : AppColors.textSecondary;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor),
                  color: AppColors.surfaceOverlay,
                ),
                child: Icon(icon, size: 19, color: iconColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _SessionNavItem {
  const _SessionNavItem(this.tab, this.label, this.icon);

  final AppTab tab;
  final String label;
  final IconData icon;
}

class _BasicConfigResult {
  const _BasicConfigResult({
    required this.sessionName,
    required this.userDescription,
  });

  final String sessionName;
  final String userDescription;
}

class _BasicConfigPage extends StatefulWidget {
  const _BasicConfigPage({
    required this.initialName,
    required this.initialUserDescription,
  });

  final String initialName;
  final String initialUserDescription;

  @override
  State<_BasicConfigPage> createState() => _BasicConfigPageState();
}

class _BasicConfigPageState extends State<_BasicConfigPage> {
  late final TextEditingController _nameController;
  late String _userDescription;
  late final String _initialName;
  late final String _initialUserDescription;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _initialName = widget.initialName;
    _userDescription = widget.initialUserDescription;
    _initialUserDescription = widget.initialUserDescription;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<_BasicConfigResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldClose = await _handleAttemptDismiss();
        if (!mounted || !shouldClose) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () async {
              final shouldClose = await _handleAttemptDismiss();
              if (!mounted || !shouldClose) {
                return;
              }
              Navigator.of(this.context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('基本配置'),
          actions: [
            TextButton(onPressed: _submit, child: const Text('保存')),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            GlassPanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('会话名称', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(controller: _nameController),
                ],
              ),
            ),
            const SizedBox(height: 10),
            _ActionCard(
              title: '用户描述',
              subtitle: _userDescription.trim().isEmpty
                  ? '点击进入设定输入框'
                  : _shortPreview(_userDescription),
              onTap: _openUserDescriptionEditor,
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _submit, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  Future<void> _openUserDescriptionEditor() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (context) => SettingInputEditorPage(
          title: '用户描述',
          fieldLabel: '用户描述',
          initialValue: _userDescription,
          hintText: '在这里描述你的身份、说话风格和交互偏好。',
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    setState(() {
      _userDescription = result;
    });
  }

  String _shortPreview(String text) {
    final normalized = text.replaceAll('\n', ' ').trim();
    if (normalized.length <= 42) {
      return normalized;
    }
    return '${normalized.substring(0, 42)}...';
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会话名称不能为空')));
      return;
    }
    Navigator.of(context).pop(
      _BasicConfigResult(sessionName: name, userDescription: _userDescription),
    );
  }

  Future<bool> _handleAttemptDismiss() async {
    if (!_isDirty()) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('你已经修改了内容，现在返回会丢失本次填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  bool _isDirty() {
    return _nameController.text != _initialName ||
        _userDescription != _initialUserDescription;
  }
}

class _WorldBookEditorResult {
  const _WorldBookEditorResult({
    required this.worldBookId,
    required this.worldDescription,
    required this.characterDescription,
  });

  final String? worldBookId;
  final String worldDescription;
  final String characterDescription;
}

class _WorldBookEditorPage extends StatefulWidget {
  const _WorldBookEditorPage({
    required this.options,
    required this.initialWorldBookId,
    required this.initialWorldDescription,
    required this.initialCharacterDescription,
  });

  final List<SessionSettingsOptionEntry> options;
  final String? initialWorldBookId;
  final String initialWorldDescription;
  final String initialCharacterDescription;

  @override
  State<_WorldBookEditorPage> createState() => _WorldBookEditorPageState();
}

class _WorldBookEditorPageState extends State<_WorldBookEditorPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String? _worldBookId;
  late String _worldDescription;
  late String _characterDescription;
  late final String? _initialWorldBookId;
  late final String _initialWorldDescription;
  late final String _initialCharacterDescription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _worldBookId = widget.initialWorldBookId;
    _initialWorldBookId = widget.initialWorldBookId;
    _worldDescription = widget.initialWorldDescription;
    _initialWorldDescription = widget.initialWorldDescription;
    _characterDescription = widget.initialCharacterDescription;
    _initialCharacterDescription = widget.initialCharacterDescription;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final optionIds = widget.options.map((item) => item.id).toSet();
    final selected = _worldBookId != null && optionIds.contains(_worldBookId)
        ? _worldBookId
        : null;

    return PopScope<_WorldBookEditorResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldClose = await _handleAttemptDismiss();
        if (!mounted || !shouldClose) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () async {
              final shouldClose = await _handleAttemptDismiss();
              if (!mounted || !shouldClose) {
                return;
              }
              Navigator.of(this.context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('世界书'),
          bottom: TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: '世界描述'),
              Tab(text: '人物设定'),
            ],
          ),
          actions: [
            TextButton(onPressed: _submit, child: const Text('保存')),
            const SizedBox(width: 4),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: GlassPanelCard(
                child: DropdownButtonFormField<String?>(
                  initialValue: selected,
                  items: <DropdownMenuItem<String?>>[
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('不绑定'),
                    ),
                    ...widget.options.map(
                      (item) => DropdownMenuItem<String?>(
                        value: item.id,
                        child: Text(item.label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _worldBookId = value;
                    });
                  },
                  decoration: const InputDecoration(labelText: '对应世界书'),
                ),
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildTabContent(
                    title: '世界描述条目占位',
                    value: _worldDescription,
                    onClear: () {
                      setState(() {
                        _worldDescription = '';
                      });
                    },
                    onEdit: () => _openSettingEditor(
                      title: '世界描述',
                      label: '世界描述',
                      currentValue: _worldDescription,
                      onSaved: (value) {
                        setState(() {
                          _worldDescription = value;
                        });
                      },
                    ),
                  ),
                  _buildTabContent(
                    title: '人物设定条目占位',
                    value: _characterDescription,
                    onClear: () {
                      setState(() {
                        _characterDescription = '';
                      });
                    },
                    onEdit: () => _openSettingEditor(
                      title: '人物设定',
                      label: '人物设定',
                      currentValue: _characterDescription,
                      onSaved: (value) {
                        setState(() {
                          _characterDescription = value;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('保存'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabContent({
    required String title,
    required String value,
    required VoidCallback onEdit,
    required VoidCallback onClear,
  }) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        GlassPanelCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text(
                value.trim().isEmpty ? '点击“编辑内容”填写此条目。' : value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: value.trim().isEmpty
                      ? AppColors.textSecondary
                      : AppColors.textStrong,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  PrimaryPillButton(label: '编辑内容', onPressed: onEdit),
                  SecondaryOutlineButton(label: '清空', onPressed: onClear),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _openSettingEditor({
    required String title,
    required String label,
    required String currentValue,
    required ValueChanged<String> onSaved,
  }) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        fullscreenDialog: true,
        builder: (context) => SettingInputEditorPage(
          title: title,
          fieldLabel: label,
          initialValue: currentValue,
          hintText: '在这里维护该条目的完整设定文本。',
        ),
      ),
    );
    if (result == null || !mounted) {
      return;
    }
    onSaved(result);
  }

  void _submit() {
    Navigator.of(context).pop(
      _WorldBookEditorResult(
        worldBookId: _worldBookId,
        worldDescription: _worldDescription,
        characterDescription: _characterDescription,
      ),
    );
  }

  Future<bool> _handleAttemptDismiss() async {
    if (!_isDirty()) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('你已经修改了内容，现在返回会丢失本次填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  bool _isDirty() {
    return _worldBookId != _initialWorldBookId ||
        _worldDescription != _initialWorldDescription ||
        _characterDescription != _initialCharacterDescription;
  }
}

class _AppearanceEditorResult {
  const _AppearanceEditorResult({
    required this.appearanceId,
    required this.backgroundImagePath,
  });

  final String appearanceId;
  final String backgroundImagePath;
}

class _AppearanceEditorPage extends StatefulWidget {
  const _AppearanceEditorPage({
    required this.options,
    required this.initialAppearanceId,
    required this.initialBackgroundPath,
  });

  final List<SessionSettingsOptionEntry> options;
  final String initialAppearanceId;
  final String initialBackgroundPath;

  @override
  State<_AppearanceEditorPage> createState() => _AppearanceEditorPageState();
}

class _AppearanceEditorPageState extends State<_AppearanceEditorPage> {
  late String _appearanceId;
  late String _backgroundPath;
  late final TextEditingController _backgroundController;
  late final String _initialAppearanceId;
  late final String _initialBackgroundPath;

  @override
  void initState() {
    super.initState();
    _appearanceId = widget.initialAppearanceId;
    _initialAppearanceId = widget.initialAppearanceId;
    _backgroundPath = widget.initialBackgroundPath;
    _initialBackgroundPath = widget.initialBackgroundPath;
    _backgroundController = TextEditingController(
      text: widget.initialBackgroundPath,
    );
  }

  @override
  void dispose() {
    _backgroundController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final optionIds = widget.options.map((item) => item.id).toSet();
    final selected = optionIds.contains(_appearanceId) ? _appearanceId : null;

    return PopScope<_AppearanceEditorResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldClose = await _handleAttemptDismiss();
        if (!mounted || !shouldClose) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () async {
              final shouldClose = await _handleAttemptDismiss();
              if (!mounted || !shouldClose) {
                return;
              }
              Navigator.of(this.context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: const Text('外观设置'),
          actions: [
            TextButton(onPressed: _submit, child: const Text('保存')),
            const SizedBox(width: 4),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
          children: [
            GlassPanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('选用的主题', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selected,
                    items: widget.options
                        .map(
                          (item) => DropdownMenuItem<String>(
                            value: item.id,
                            child: Text(item.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) {
                        return;
                      }
                      setState(() {
                        _appearanceId = value;
                      });
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            GlassPanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('背景图片', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _backgroundController,
                    decoration: const InputDecoration(
                      labelText: '图片路径',
                      hintText: '未设置时使用默认背景',
                    ),
                    onChanged: (value) {
                      setState(() {
                        _backgroundPath = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      PrimaryPillButton(
                        label: '选择图片',
                        onPressed: _pickBackgroundImage,
                      ),
                      SecondaryOutlineButton(
                        label: '清空',
                        onPressed: () {
                          setState(() {
                            _backgroundPath = '';
                            _backgroundController.clear();
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _submit, child: const Text('保存')),
          ],
        ),
      ),
    );
  }

  Future<void> _pickBackgroundImage() async {
    final picked = await pickImageFile();
    if (picked == null || !mounted) {
      return;
    }
    setState(() {
      _backgroundPath = picked;
      _backgroundController.text = picked;
    });
  }

  void _submit() {
    Navigator.of(context).pop(
      _AppearanceEditorResult(
        appearanceId: _appearanceId,
        backgroundImagePath: _backgroundPath.trim(),
      ),
    );
  }

  Future<bool> _handleAttemptDismiss() async {
    if (!_isDirty()) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('你已经修改了内容，现在返回会丢失本次填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  bool _isDirty() {
    return _appearanceId != _initialAppearanceId ||
        _backgroundPath != _initialBackgroundPath;
  }
}

class SettingInputEditorPage extends StatefulWidget {
  const SettingInputEditorPage({
    super.key,
    required this.title,
    required this.fieldLabel,
    required this.initialValue,
    required this.hintText,
  });

  final String title;
  final String fieldLabel;
  final String initialValue;
  final String hintText;

  @override
  State<SettingInputEditorPage> createState() => _SettingInputEditorPageState();
}

class _SettingInputEditorPageState extends State<SettingInputEditorPage> {
  late final TextEditingController _controller;
  late final String _initialValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _initialValue = widget.initialValue;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<String>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) {
          return;
        }
        final shouldClose = await _handleAttemptDismiss();
        if (!mounted || !shouldClose) {
          return;
        }
        Navigator.of(this.context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            tooltip: '返回',
            onPressed: () async {
              final shouldClose = await _handleAttemptDismiss();
              if (!mounted || !shouldClose) {
                return;
              }
              Navigator.of(this.context).pop();
            },
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(widget.title),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(_controller.text),
              child: const Text('保存'),
            ),
            const SizedBox(width: 4),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 18),
            child: GlassPanelCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.fieldLabel,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    widget.hintText,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      expands: true,
                      minLines: null,
                      maxLines: null,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: const InputDecoration(
                        hintText: '请输入内容...',
                        alignLabelWithHint: true,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _handleAttemptDismiss() async {
    if (_controller.text == _initialValue) {
      return true;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('放弃未保存的修改？'),
        content: const Text('你已经修改了内容，现在返回会丢失本次填写。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('放弃修改'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }
}

Future<String?> pickImageFile() async {
  try {
    const images = XTypeGroup(
      label: 'images',
      extensions: <String>['png', 'jpg', 'jpeg', 'webp', 'bmp'],
    );
    final selected = await openFile(
      acceptedTypeGroups: <XTypeGroup>[images],
      confirmButtonText: '选择背景图',
    );
    return selected?.path;
  } catch (_) {
    return null;
  }
}
