import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
    final next = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.backgroundElevated,
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
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(10, 6, 10, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.backgroundElevated.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderSubtle),
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
                    child: TextField(
                      controller: widget.controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      style: const TextStyle(color: AppColors.textStrong),
                      decoration: const InputDecoration(
                        isCollapsed: true,
                        hintText: '随便聊聊...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        border: InputBorder.none,
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
                        backgroundColor: AppColors.textStrong.withValues(
                          alpha: 0.9,
                        ),
                        foregroundColor: AppColors.backgroundBase,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
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
                    color: AppColors.backgroundBase.withValues(alpha: 0.24),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.borderSubtle),
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
            foregroundColor: AppColors.textSecondary,
            backgroundColor: AppColors.surfaceOverlay.withValues(alpha: 0.7),
            side: const BorderSide(color: AppColors.borderSubtle),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
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
        color: AppColors.surfaceOverlay.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.borderSubtle),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
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
      backgroundColor: AppColors.backgroundElevated,
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
                  const Expanded(
                    child: Text(
                      '全屏输入',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textStrong,
                        fontSize: 16,
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
            const Divider(height: 1, color: AppColors.borderSubtle),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: TextField(
                  controller: _controller,
                  focusNode: _focusNode,
                  keyboardType: TextInputType.multiline,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    color: AppColors.textStrong,
                    height: 1.45,
                  ),
                  decoration: const InputDecoration(
                    hintText: '输入内容...',
                    hintStyle: TextStyle(color: AppColors.textMuted),
                    border: InputBorder.none,
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
