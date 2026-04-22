import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/theme_tokens.dart';
import '../utils/responsive.dart';

class _SendComposerIntent extends Intent {
  const _SendComposerIntent();
}

class FloatingComposer extends StatefulWidget {
  const FloatingComposer({
    super.key,
    required this.controller,
    required this.onSend,
    this.focusNode,
    this.isSending = false,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final VoidCallback onSend;
  final bool isSending;

  @override
  State<FloatingComposer> createState() => _FloatingComposerState();
}

class _FloatingComposerState extends State<FloatingComposer> {
  FocusNode? _internalFocusNode;
  FocusNode? _attachedNode;
  bool _isFocused = false;

  FocusNode get _effectiveFocusNode =>
      widget.focusNode ?? (_internalFocusNode ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _bindFocusNode();
  }

  @override
  void didUpdateWidget(covariant FloatingComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      _unbindFocusNode();
      _bindFocusNode();
    }
  }

  @override
  void dispose() {
    _unbindFocusNode();
    _internalFocusNode?.dispose();
    super.dispose();
  }

  void _bindFocusNode() {
    final node = _effectiveFocusNode;
    _attachedNode = node;
    _isFocused = node.hasFocus;
    node.addListener(_handleFocusChanged);
  }

  void _unbindFocusNode() {
    _attachedNode?.removeListener(_handleFocusChanged);
    _attachedNode = null;
  }

  void _handleFocusChanged() {
    final focused = _effectiveFocusNode.hasFocus;
    if (focused == _isFocused || !mounted) {
      return;
    }
    setState(() {
      _isFocused = focused;
    });
  }

  void _insertWrapped(String left, String right) {
    final controller = widget.controller;
    final selection = controller.selection;
    final fallback = controller.text.length;
    var start = selection.isValid ? selection.start : fallback;
    var end = selection.isValid ? selection.end : fallback;
    if (start < 0 || end < 0) {
      start = fallback;
      end = fallback;
    }
    if (start > end) {
      final temp = start;
      start = end;
      end = temp;
    }

    final original = controller.text;
    final selected = original.substring(start, end);
    final replacement = '$left$selected$right';
    final replaced = original.replaceRange(start, end, replacement);
    final cursor = selected.isEmpty
        ? start + left.length
        : start + replacement.length;
    controller.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
    _effectiveFocusNode.requestFocus();
  }

  Future<void> _openFullscreenComposer() async {
    final initialText = widget.controller.text;

    if (Responsive.isDesktop(context)) {
      final next = await showDialog<String>(
        context: context,
        builder: (context) {
          return Dialog(
            backgroundColor: AppThemeTokens.background(context),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppThemeTokens.radiusCard(context),
              ),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640, maxHeight: 600),
              child: _FullscreenComposerSheet(
                initialText: initialText,
                isSending: widget.isSending,
                onSend: widget.onSend,
              ),
            ),
          );
        },
      );
      if (next == null) {
        return;
      }
      widget.controller.value = TextEditingValue(
        text: next,
        selection: TextSelection.collapsed(offset: next.length),
      );
      _effectiveFocusNode.requestFocus();
      return;
    }

    final next = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppThemeTokens.background(context),
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 1,
          child: _FullscreenComposerSheet(
            initialText: initialText,
            isSending: widget.isSending,
            onSend: widget.onSend,
          ),
        );
      },
    );
    if (next == null) {
      return;
    }
    widget.controller.value = TextEditingValue(
      text: next,
      selection: TextSelection.collapsed(offset: next.length),
    );
    _effectiveFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final focusNode = _effectiveFocusNode;
    final isLightTheme = AppThemeTokens.isLight(context);
    final sendBackground = AppThemeTokens.primary(context);
    final sendForeground = Theme.of(context).colorScheme.onPrimary;
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppThemeTokens.background(
            context,
          ).withValues(alpha: isLightTheme ? 0.98 : 0.94),
          borderRadius: BorderRadius.circular(
            AppThemeTokens.radiusField(context),
          ),
          border: Border.all(color: AppThemeTokens.border(context)),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Shortcuts(
                      shortcuts: const <ShortcutActivator, Intent>{
                        SingleActivator(
                          LogicalKeyboardKey.enter,
                          control: true,
                        ): _SendComposerIntent(),
                        SingleActivator(
                          LogicalKeyboardKey.numpadEnter,
                          control: true,
                        ): _SendComposerIntent(),
                      },
                      child: Actions(
                        actions: <Type, Action<Intent>>{
                          _SendComposerIntent:
                              CallbackAction<_SendComposerIntent>(
                                onInvoke: (_) {
                                  if (!focusNode.hasFocus) {
                                    return null;
                                  }
                                  widget.onSend();
                                  return null;
                                },
                              ),
                        },
                        child: TextField(
                          controller: widget.controller,
                          focusNode: focusNode,
                          minLines: 1,
                          maxLines: 4,
                          textInputAction: TextInputAction.newline,
                          style: TextStyle(
                            color: AppThemeTokens.textStrong(context),
                          ),
                          decoration: InputDecoration(
                            isCollapsed: true,
                            hintText: '随便聊聊...',
                            hintStyle: TextStyle(
                              color: AppThemeTokens.textMuted(context),
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: IconButton(
                      onPressed: widget.onSend,
                      padding: EdgeInsets.zero,
                      style: IconButton.styleFrom(
                        backgroundColor: sendBackground,
                        foregroundColor: sendForeground,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppThemeTokens.radiusPill(context),
                          ),
                        ),
                      ),
                      icon: Icon(
                        widget.isSending
                            ? Icons.stop_rounded
                            : Icons.arrow_upward_rounded,
                        size: 15,
                      ),
                    ),
                  ),
                ],
              ),
              if (_isFocused) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
                  decoration: BoxDecoration(
                    color: AppThemeTokens.panelMuted(
                      context,
                    ).withValues(alpha: isLightTheme ? 0.72 : 0.24),
                    borderRadius: BorderRadius.circular(
                      AppThemeTokens.radiusMedium(context),
                    ),
                    border: Border.all(color: AppThemeTokens.border(context)),
                  ),
                  child: Row(
                    children: [
                      _QuickActionIconButton(
                        tooltip: '全屏输入',
                        icon: Icons.fullscreen_rounded,
                        onPressed: _openFullscreenComposer,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                _ComposerShortcutChip(
                                  label: '()',
                                  onTap: () => _insertWrapped('(', ')'),
                                ),
                                _ComposerShortcutChip(
                                  label: '""',
                                  onTap: () => _insertWrapped('"', '"'),
                                ),
                                _ComposerShortcutChip(
                                  label: '*',
                                  onTap: () => _insertWrapped('*', '*'),
                                ),
                                _ComposerShortcutChip(
                                  label: '{}',
                                  onTap: () => _insertWrapped('{', '}'),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickActionIconButton extends StatelessWidget {
  const _QuickActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: SizedBox(
        width: 30,
        height: 30,
        child: IconButton(
          onPressed: onPressed,
          padding: EdgeInsets.zero,
          style: IconButton.styleFrom(
            foregroundColor: AppThemeTokens.textSecondary(context),
            backgroundColor: AppThemeTokens.panel(
              context,
            ).withValues(alpha: AppThemeTokens.isLight(context) ? 0.9 : 0.7),
            side: BorderSide(color: AppThemeTokens.border(context)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(
                AppThemeTokens.radiusSmall(context),
              ),
            ),
          ),
          icon: Icon(icon, size: 16),
        ),
      ),
    );
  }
}

class _ComposerShortcutChip extends StatelessWidget {
  const _ComposerShortcutChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: AppThemeTokens.panel(
          context,
        ).withValues(alpha: AppThemeTokens.isLight(context) ? 0.9 : 0.7),
        borderRadius: BorderRadius.circular(
          AppThemeTokens.radiusSmall(context),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(
            AppThemeTokens.radiusSmall(context),
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                AppThemeTokens.radiusSmall(context),
              ),
              border: Border.all(color: AppThemeTokens.border(context)),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppThemeTokens.textSecondary(context),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FullscreenComposerSheet extends StatefulWidget {
  const _FullscreenComposerSheet({
    required this.initialText,
    required this.isSending,
    required this.onSend,
  });

  final String initialText;
  final bool isSending;
  final VoidCallback onSend;

  @override
  State<_FullscreenComposerSheet> createState() =>
      _FullscreenComposerSheetState();
}

class _FullscreenComposerSheetState extends State<_FullscreenComposerSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialText);
    _focusNode = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _focusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _closeWithValue() {
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppThemeTokens.background(context),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: '关闭',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '全屏输入',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppThemeTokens.textStrong(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _closeWithValue,
                    child: const Text('应用'),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: widget.isSending ? '停止' : '发送',
                    onPressed: () {
                      _closeWithValue();
                      widget.onSend();
                    },
                    icon: Icon(
                      widget.isSending
                          ? Icons.stop_rounded
                          : Icons.arrow_upward_rounded,
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AppThemeTokens.border(context)),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Shortcuts(
                  shortcuts: const <ShortcutActivator, Intent>{
                    SingleActivator(LogicalKeyboardKey.enter, control: true):
                        _SendComposerIntent(),
                    SingleActivator(
                      LogicalKeyboardKey.numpadEnter,
                      control: true,
                    ): _SendComposerIntent(),
                  },
                  child: Actions(
                    actions: <Type, Action<Intent>>{
                      _SendComposerIntent: CallbackAction<_SendComposerIntent>(
                        onInvoke: (_) {
                          if (!_focusNode.hasFocus) {
                            return null;
                          }
                          _closeWithValue();
                          widget.onSend();
                          return null;
                        },
                      ),
                    },
                    child: TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      keyboardType: TextInputType.multiline,
                      maxLines: null,
                      expands: true,
                      textAlignVertical: TextAlignVertical.top,
                      style: TextStyle(
                        color: AppThemeTokens.textStrong(context),
                        height: 1.45,
                      ),
                      decoration: InputDecoration(
                        hintText: '输入内容...',
                        hintStyle: TextStyle(
                          color: AppThemeTokens.textMuted(context),
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
