import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:json2yaml/json2yaml.dart';
import 'package:yaml/yaml.dart';

import '../theme/app_colors.dart';

enum StructuredTextFormat { plain, markdown, yaml, json }

extension StructuredTextFormatLabel on StructuredTextFormat {
  String get label => switch (this) {
    StructuredTextFormat.plain => '文本',
    StructuredTextFormat.markdown => 'Markdown',
    StructuredTextFormat.yaml => 'YAML',
    StructuredTextFormat.json => 'JSON',
  };
}

class StructuredTextEditor extends StatefulWidget {
  const StructuredTextEditor({
    super.key,
    required this.initialText,
    required this.onChanged,
    this.hintText = '在这里编辑内容',
    this.height = 420,
    this.initialFormat,
  });

  final String initialText;
  final ValueChanged<String> onChanged;
  final String hintText;
  final double height;
  final StructuredTextFormat? initialFormat;

  @override
  State<StructuredTextEditor> createState() => _StructuredTextEditorState();
}

class _StructuredTextEditorState extends State<StructuredTextEditor> {
  late final _StructuredContentController _controller;
  late final _StructuredContentFormatter _formatter;
  late final FocusNode _focusNode;
  late StructuredTextFormat _selectedFormat;
  late _EditorContentStatus _status;
  Timer? _autoFormatTimer;
  bool _applyingAutoFormat = false;
  bool _syncingHighlights = false;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = _StructuredContentController(text: widget.initialText);
    _selectedFormat =
        widget.initialFormat ??
        _EditorContentStatus.detectKind(widget.initialText);
    _formatter = _StructuredContentFormatter(
      currentKind: () => _selectedFormat,
    );
    _focusNode = FocusNode();
    _status = _EditorContentStatus.analyze(
      widget.initialText,
      preferredKind: _selectedFormat,
    );
    _controller.applyStatus(_status);
    _controller.addListener(_handleContentChanged);
    _focusNode.addListener(_handleFocusChanged);
  }

  @override
  void didUpdateWidget(covariant StructuredTextEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialText != oldWidget.initialText &&
        widget.initialText != _controller.text) {
      final preferredFormat =
          widget.initialFormat ??
          _EditorContentStatus.detectKind(widget.initialText);
      _selectedFormat = preferredFormat;
      _status = _EditorContentStatus.analyze(
        widget.initialText,
        preferredKind: preferredFormat,
      );
      _syncingHighlights = true;
      _controller
        ..value = TextEditingValue(
          text: widget.initialText,
          selection: TextSelection.collapsed(offset: widget.initialText.length),
        )
        ..applyStatus(_status);
      _syncingHighlights = false;
    }
  }

  @override
  void dispose() {
    _autoFormatTimer?.cancel();
    _focusNode
      ..removeListener(_handleFocusChanged)
      ..dispose();
    _controller
      ..removeListener(_handleContentChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final status = _status;
    return Container(
      height: widget.height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: status.hasIssue
              ? AppColors.warning.withValues(alpha: 0.72)
              : AppColors.borderSubtle,
        ),
        color: AppColors.surfaceOverlay.withValues(alpha: 0.42),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ...StructuredTextFormat.values.map(
                  (format) => _FormatChip(
                    label: format.label,
                    selected: format == _selectedFormat,
                    onTap: () => _selectFormat(format),
                  ),
                ),
                if (status.message != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Text(
                      status.message!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: status.hasIssue
                            ? AppColors.warning
                            : AppColors.textSecondary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(
            height: 1,
            thickness: 1,
            color: AppColors.borderSubtle.withValues(alpha: 0.8),
          ),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              inputFormatters: [_formatter],
              expands: true,
              minLines: null,
              maxLines: null,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                height: 1.5,
              ),
              decoration: InputDecoration(
                hintText: widget.hintText,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 140),
            child: _isFocused
                ? _StructuredEditorAssistBar(
                    onFullscreen: _openFullscreenEditor,
                    onInsertColon: () => _insertLiteral(':'),
                    onInsertDoubleQuote: () => _insertWrapped('"', '"'),
                    onInsertBraces: () => _insertWrapped('{', '}'),
                    onInsertBrackets: () => _insertWrapped('[', ']'),
                    onInsertParentheses: () => _insertWrapped('(', ')'),
                    onInsertHash: () => _insertLiteral('#'),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  void _handleFocusChanged() {
    final focused = _focusNode.hasFocus;
    if (_isFocused == focused || !mounted) {
      return;
    }
    setState(() {
      _isFocused = focused;
    });
  }

  void _insertLiteral(String value) {
    final selection = _controller.selection;
    final fallback = _controller.text.length;
    var start = selection.isValid ? selection.start : fallback;
    var end = selection.isValid ? selection.end : fallback;
    if (start < 0 || end < 0) {
      start = fallback;
      end = fallback;
    }
    if (start > end) {
      final tmp = start;
      start = end;
      end = tmp;
    }

    final replaced = _controller.text.replaceRange(start, end, value);
    final cursor = start + value.length;
    _controller.value = TextEditingValue(
      text: replaced,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _insertWrapped(String left, String right) {
    final selection = _controller.selection;
    final fallback = _controller.text.length;
    var start = selection.isValid ? selection.start : fallback;
    var end = selection.isValid ? selection.end : fallback;
    if (start < 0 || end < 0) {
      start = fallback;
      end = fallback;
    }
    if (start > end) {
      final tmp = start;
      start = end;
      end = tmp;
    }

    final selected = _controller.text.substring(start, end);
    final replacement = '$left$selected$right';
    final replaced = _controller.text.replaceRange(start, end, replacement);
    final nextSelection = selected.isEmpty
        ? TextSelection.collapsed(offset: start + left.length)
        : TextSelection(
            baseOffset: start + left.length,
            extentOffset: start + left.length + selected.length,
          );
    _controller.value = TextEditingValue(
      text: replaced,
      selection: nextSelection,
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  Future<void> _openFullscreenEditor() async {
    final nextText = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.backgroundElevated,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 1,
          child: _FullscreenStructuredEditorSheet(
            initialText: _controller.text,
            hintText: widget.hintText,
          ),
        );
      },
    );
    if (nextText == null) {
      return;
    }
    _controller.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextText.length),
      composing: TextRange.empty,
    );
    _focusNode.requestFocus();
  }

  void _handleContentChanged() {
    if (_syncingHighlights) {
      return;
    }
    final text = _controller.text;
    final status = _EditorContentStatus.analyze(
      text,
      preferredKind: _selectedFormat,
    );
    _syncingHighlights = true;
    _controller.applyStatus(status);
    _syncingHighlights = false;
    setState(() {
      _status = status;
    });
    widget.onChanged(text);

    if (_applyingAutoFormat) {
      return;
    }
    _autoFormatTimer?.cancel();
    if (!status.shouldAutoFormat) {
      return;
    }
    _autoFormatTimer = Timer(const Duration(milliseconds: 320), () {
      if (!mounted) {
        return;
      }
      final current = _controller.text;
      final formatted = _EditorContentStatus.format(
        current,
        format: _selectedFormat,
      );
      if (formatted == null || formatted == current) {
        return;
      }
      _applyingAutoFormat = true;
      _controller.value = TextEditingValue(
        text: formatted,
        selection: _remapSelection(
          before: current,
          after: formatted,
          selection: _controller.selection,
        ),
        composing: TextRange.empty,
      );
      _applyingAutoFormat = false;
    });
  }

  void _selectFormat(StructuredTextFormat format) {
    if (format == _selectedFormat) {
      return;
    }
    final status = _EditorContentStatus.analyze(
      _controller.text,
      preferredKind: format,
    );
    _syncingHighlights = true;
    _controller.applyStatus(status);
    _syncingHighlights = false;
    setState(() {
      _selectedFormat = format;
      _status = status;
    });
  }

  TextSelection _remapSelection({
    required String before,
    required String after,
    required TextSelection selection,
  }) {
    int remapOffset(int offset) {
      if (offset < 0) {
        return offset;
      }
      final prefixLength = _commonPrefixLength(before, after);
      final suffixLength = _commonSuffixLength(before, after, prefixLength);
      if (offset <= prefixLength) {
        return offset.clamp(0, after.length);
      }
      if (offset >= before.length - suffixLength) {
        final distanceFromEnd = before.length - offset;
        return (after.length - distanceFromEnd).clamp(0, after.length);
      }
      return prefixLength.clamp(0, after.length);
    }

    return TextSelection(
      baseOffset: remapOffset(selection.baseOffset),
      extentOffset: remapOffset(selection.extentOffset),
      affinity: selection.affinity,
      isDirectional: selection.isDirectional,
    );
  }

  int _commonPrefixLength(String before, String after) {
    final limit = before.length < after.length ? before.length : after.length;
    var index = 0;
    while (index < limit &&
        before.codeUnitAt(index) == after.codeUnitAt(index)) {
      index += 1;
    }
    return index;
  }

  int _commonSuffixLength(String before, String after, int prefixLength) {
    var count = 0;
    while (count < before.length - prefixLength &&
        count < after.length - prefixLength &&
        before.codeUnitAt(before.length - count - 1) ==
            after.codeUnitAt(after.length - count - 1)) {
      count += 1;
    }
    return count;
  }
}

class _FormatChip extends StatelessWidget {
  const _FormatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tint = selected ? AppColors.accentSecondary : AppColors.textMuted;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: tint.withValues(alpha: selected ? 0.18 : 0.08),
          border: Border.all(
            color: tint.withValues(alpha: selected ? 0.52 : 0.22),
          ),
        ),
        child: Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelLarge?.copyWith(color: tint, fontSize: 12),
        ),
      ),
    );
  }
}

class _StructuredEditorAssistBar extends StatelessWidget {
  const _StructuredEditorAssistBar({
    required this.onFullscreen,
    required this.onInsertColon,
    required this.onInsertDoubleQuote,
    required this.onInsertBraces,
    required this.onInsertBrackets,
    required this.onInsertParentheses,
    required this.onInsertHash,
  });

  final VoidCallback onFullscreen;
  final VoidCallback onInsertColon;
  final VoidCallback onInsertDoubleQuote;
  final VoidCallback onInsertBraces;
  final VoidCallback onInsertBrackets;
  final VoidCallback onInsertParentheses;
  final VoidCallback onInsertHash;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey<String>('structured-editor-assist-bar'),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppColors.borderSubtle.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          _AssistIconButton(
            tooltip: '全屏编辑',
            icon: Icons.fullscreen_rounded,
            onPressed: onFullscreen,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _AssistShortcutChip(label: ':', onTap: onInsertColon),
                    _AssistShortcutChip(
                      label: '""',
                      onTap: onInsertDoubleQuote,
                    ),
                    _AssistShortcutChip(label: '{}', onTap: onInsertBraces),
                    _AssistShortcutChip(label: '[]', onTap: onInsertBrackets),
                    _AssistShortcutChip(
                      label: '()',
                      onTap: onInsertParentheses,
                    ),
                    _AssistShortcutChip(label: '#', onTap: onInsertHash),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AssistIconButton extends StatelessWidget {
  const _AssistIconButton({
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
            backgroundColor: AppColors.surfaceOverlay.withValues(alpha: 0.74),
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

class _AssistShortcutChip extends StatelessWidget {
  const _AssistShortcutChip({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Material(
        color: AppColors.surfaceOverlay.withValues(alpha: 0.72),
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

class _FullscreenStructuredEditorSheet extends StatefulWidget {
  const _FullscreenStructuredEditorSheet({
    required this.initialText,
    required this.hintText,
  });

  final String initialText;
  final String hintText;

  @override
  State<_FullscreenStructuredEditorSheet> createState() =>
      _FullscreenStructuredEditorSheetState();
}

class _FullscreenStructuredEditorSheetState
    extends State<_FullscreenStructuredEditorSheet> {
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

  void _applyAndClose() {
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
                      '全屏编辑',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: AppColors.textStrong,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  TextButton(onPressed: _applyAndClose, child: const Text('应用')),
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
                    fontFamily: 'monospace',
                    fontSize: 13,
                    height: 1.5,
                  ),
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: const TextStyle(color: AppColors.textMuted),
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

class _StructuredContentController extends TextEditingController {
  _StructuredContentController({required super.text});

  List<TextRange> _highlightRanges = const <TextRange>[];

  void applyStatus(_EditorContentStatus status) {
    if (_hasSameRanges(status.highlightRanges)) {
      return;
    }
    _highlightRanges = status.highlightRanges;
    notifyListeners();
  }

  bool _hasSameRanges(List<TextRange> other) {
    if (_highlightRanges.length != other.length) {
      return false;
    }
    for (var index = 0; index < other.length; index += 1) {
      if (_highlightRanges[index].start != other[index].start ||
          _highlightRanges[index].end != other[index].end) {
        return false;
      }
    }
    return true;
  }

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final baseStyle = style ?? const TextStyle();
    if (_highlightRanges.isEmpty) {
      return super.buildTextSpan(
        context: context,
        style: style,
        withComposing: withComposing,
      );
    }

    final boundaries = <int>{0, text.length};
    for (final range in _highlightRanges) {
      boundaries.add(range.start.clamp(0, text.length));
      boundaries.add(range.end.clamp(0, text.length));
    }

    final composingRange =
        withComposing &&
            value.isComposingRangeValid &&
            !value.composing.isCollapsed
        ? value.composing
        : TextRange.empty;
    if (!composingRange.isCollapsed) {
      boundaries.add(composingRange.start);
      boundaries.add(composingRange.end);
    }

    final sortedBoundaries = boundaries.toList()..sort();
    final children = <InlineSpan>[];
    for (var index = 0; index < sortedBoundaries.length - 1; index += 1) {
      final start = sortedBoundaries[index];
      final end = sortedBoundaries[index + 1];
      if (start >= end) {
        continue;
      }
      var segmentStyle = baseStyle;
      if (_isHighlighted(start, end)) {
        segmentStyle = segmentStyle.merge(
          const TextStyle(
            decoration: TextDecoration.underline,
            decorationColor: AppColors.warning,
            decorationThickness: 2,
          ),
        );
      }
      if (!composingRange.isCollapsed &&
          start >= composingRange.start &&
          end <= composingRange.end) {
        segmentStyle = segmentStyle.merge(
          const TextStyle(decoration: TextDecoration.underline),
        );
      }
      children.add(
        TextSpan(text: text.substring(start, end), style: segmentStyle),
      );
    }
    return TextSpan(style: baseStyle, children: children);
  }

  bool _isHighlighted(int start, int end) {
    for (final range in _highlightRanges) {
      if (start >= range.start && end <= range.end) {
        return true;
      }
    }
    return false;
  }
}

class _StructuredContentFormatter extends TextInputFormatter {
  _StructuredContentFormatter({required this.currentKind});

  final StructuredTextFormat Function() currentKind;

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (!newValue.composing.isCollapsed || !oldValue.composing.isCollapsed) {
      return newValue;
    }

    final change = _TextChange.diff(oldValue, newValue);
    if (change == null) {
      return newValue;
    }

    final kind = currentKind();
    if (change.inserted == '\t') {
      return _replaceSelection(
        oldValue,
        change.start,
        change.end,
        _indentUnit(kind),
      );
    }

    if (change.inserted == '\n') {
      final handled = _handleNewline(oldValue, change, kind);
      if (handled != null) {
        return handled;
      }
    }

    if (change.inserted.length != 1) {
      return newValue;
    }

    final inserted = change.inserted;
    final pairMap = _pairMap(kind);

    if (pairMap.containsKey(inserted)) {
      return _handleOpenPair(oldValue, change, inserted, pairMap[inserted]!);
    }

    if (pairMap.containsValue(inserted)) {
      final skipped = _handleClosingSkip(oldValue, change, inserted);
      if (skipped != null) {
        return skipped;
      }
    }

    return newValue;
  }

  TextEditingValue? _handleNewline(
    TextEditingValue oldValue,
    _TextChange change,
    StructuredTextFormat kind,
  ) {
    final cursor = change.start;
    final before = oldValue.text.substring(0, cursor);
    final after = oldValue.text.substring(change.end);
    final lineStart = before.lastIndexOf('\n') + 1;
    final currentLine = before.substring(lineStart);
    final currentIndent = _leadingWhitespace(currentLine);
    final trimmedLine = currentLine.trimLeft();
    final charBefore = cursor > 0 ? oldValue.text[cursor - 1] : '';
    final charAfter = cursor < oldValue.text.length
        ? oldValue.text[cursor]
        : '';

    if (kind == StructuredTextFormat.json &&
        ((charBefore == '{' && charAfter == '}') ||
            (charBefore == '[' && charAfter == ']'))) {
      final innerIndent = currentIndent + _indentUnit(kind);
      return TextEditingValue(
        text: '$before\n$innerIndent\n$currentIndent$after',
        selection: TextSelection.collapsed(
          offset: before.length + 1 + innerIndent.length,
        ),
      );
    }

    if (kind == StructuredTextFormat.yaml) {
      if (trimmedLine.startsWith('- ') && !trimmedLine.endsWith(':')) {
        return _replaceSelection(
          oldValue,
          change.start,
          change.end,
          '\n$currentIndent- ',
        );
      }
      if (trimmedLine.endsWith(':')) {
        return _replaceSelection(
          oldValue,
          change.start,
          change.end,
          '\n$currentIndent${_indentUnit(kind)}',
        );
      }
      return _replaceSelection(
        oldValue,
        change.start,
        change.end,
        '\n$currentIndent',
      );
    }

    if (kind == StructuredTextFormat.markdown) {
      final blockQuoteMatch = RegExp(r'^(>+\s?)').firstMatch(trimmedLine);
      if (blockQuoteMatch != null) {
        return _replaceSelection(
          oldValue,
          change.start,
          change.end,
          '\n$currentIndent${blockQuoteMatch.group(1)!}',
        );
      }

      final bulletMatch = RegExp(r'^([-*+])\s+').firstMatch(trimmedLine);
      if (bulletMatch != null) {
        return _replaceSelection(
          oldValue,
          change.start,
          change.end,
          '\n$currentIndent${bulletMatch.group(1)!} ',
        );
      }

      final orderedMatch = RegExp(r'^(\d+)\.\s+').firstMatch(trimmedLine);
      if (orderedMatch != null) {
        final number = int.parse(orderedMatch.group(1)!) + 1;
        return _replaceSelection(
          oldValue,
          change.start,
          change.end,
          '\n$currentIndent$number. ',
        );
      }

      return _replaceSelection(
        oldValue,
        change.start,
        change.end,
        '\n$currentIndent',
      );
    }

    if (kind == StructuredTextFormat.json &&
        (charBefore == '{' || charBefore == '[')) {
      return _replaceSelection(
        oldValue,
        change.start,
        change.end,
        '\n$currentIndent${_indentUnit(kind)}',
      );
    }

    return _replaceSelection(
      oldValue,
      change.start,
      change.end,
      '\n$currentIndent',
    );
  }

  TextEditingValue _handleOpenPair(
    TextEditingValue oldValue,
    _TextChange change,
    String open,
    String close,
  ) {
    final selectedText = oldValue.selection.textInside(oldValue.text);
    if (selectedText.isNotEmpty) {
      final wrapped = '$open$selectedText$close';
      return TextEditingValue(
        text:
            oldValue.selection.textBefore(oldValue.text) +
            wrapped +
            oldValue.selection.textAfter(oldValue.text),
        selection: TextSelection(
          baseOffset: oldValue.selection.start + 1,
          extentOffset: oldValue.selection.start + 1 + selectedText.length,
        ),
      );
    }

    final nextChar = change.start < oldValue.text.length
        ? oldValue.text[change.start]
        : '';
    if (!_shouldAutoClose(nextChar)) {
      return _replaceSelection(oldValue, change.start, change.end, open);
    }

    final replacement = '$open$close';
    return TextEditingValue(
      text:
          oldValue.text.substring(0, change.start) +
          replacement +
          oldValue.text.substring(change.end),
      selection: TextSelection.collapsed(offset: change.start + 1),
    );
  }

  TextEditingValue? _handleClosingSkip(
    TextEditingValue oldValue,
    _TextChange change,
    String closing,
  ) {
    if (!oldValue.selection.isCollapsed ||
        change.start >= oldValue.text.length ||
        oldValue.text[change.start] != closing) {
      return null;
    }
    return TextEditingValue(
      text: oldValue.text,
      selection: TextSelection.collapsed(offset: change.start + 1),
    );
  }

  TextEditingValue _replaceSelection(
    TextEditingValue oldValue,
    int start,
    int end,
    String replacement,
  ) {
    final text =
        oldValue.text.substring(0, start) +
        replacement +
        oldValue.text.substring(end);
    final offset = start + replacement.length;
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: offset),
    );
  }

  String _leadingWhitespace(String text) {
    final match = RegExp(r'^\s*').firstMatch(text);
    return match?.group(0) ?? '';
  }

  bool _shouldAutoClose(String nextChar) {
    return nextChar.isEmpty || RegExp(r'[\s\)\]\}\>,.:;]').hasMatch(nextChar);
  }

  String _indentUnit(StructuredTextFormat kind) {
    return switch (kind) {
      StructuredTextFormat.yaml || StructuredTextFormat.json => '  ',
      StructuredTextFormat.markdown || StructuredTextFormat.plain => '  ',
    };
  }

  Map<String, String> _pairMap(StructuredTextFormat kind) {
    final map = <String, String>{
      '(': ')',
      '[': ']',
      '{': '}',
      '"': '"',
      "'": "'",
    };
    if (kind == StructuredTextFormat.markdown) {
      map['`'] = '`';
    }
    return map;
  }
}

class _TextChange {
  const _TextChange({
    required this.start,
    required this.end,
    required this.inserted,
  });

  final int start;
  final int end;
  final String inserted;

  static _TextChange? diff(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final oldText = oldValue.text;
    final newText = newValue.text;
    var start = 0;
    final minLength = oldText.length < newText.length
        ? oldText.length
        : newText.length;
    while (start < minLength &&
        oldText.codeUnitAt(start) == newText.codeUnitAt(start)) {
      start += 1;
    }

    var oldEnd = oldText.length;
    var newEnd = newText.length;
    while (oldEnd > start &&
        newEnd > start &&
        oldText.codeUnitAt(oldEnd - 1) == newText.codeUnitAt(newEnd - 1)) {
      oldEnd -= 1;
      newEnd -= 1;
    }

    final inserted = newText.substring(start, newEnd);
    return _TextChange(start: start, end: oldEnd, inserted: inserted);
  }
}

class _PairAnalysis {
  const _PairAnalysis({required this.highlightRanges, this.message});

  final List<TextRange> highlightRanges;
  final String? message;
}

class _PairToken {
  const _PairToken({required this.symbol, required this.offset});

  final String symbol;
  final int offset;
}

class _EditorContentStatus {
  const _EditorContentStatus({
    required this.kind,
    required this.canFormat,
    required this.highlightRanges,
    this.message,
  });

  final StructuredTextFormat kind;
  final bool canFormat;
  final List<TextRange> highlightRanges;
  final String? message;

  bool get hasIssue => message != null || highlightRanges.isNotEmpty;
  bool get shouldAutoFormat => canFormat && !hasIssue;

  static StructuredTextFormat detectKind(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      return StructuredTextFormat.plain;
    }
    if (_looksLikeJson(trimmed)) {
      return StructuredTextFormat.json;
    }
    if (_looksLikeYaml(trimmed)) {
      return StructuredTextFormat.yaml;
    }
    if (_looksLikeMarkdown(trimmed)) {
      return StructuredTextFormat.markdown;
    }
    return StructuredTextFormat.plain;
  }

  static _EditorContentStatus analyze(
    String text, {
    StructuredTextFormat? preferredKind,
  }) {
    final trimmed = text.trim();
    final pairAnalysis = _analyzePairs(text);
    final activeKind = preferredKind ?? detectKind(text);
    if (trimmed.isEmpty) {
      return _EditorContentStatus(
        kind: activeKind,
        canFormat: false,
        highlightRanges: const <TextRange>[],
      );
    }
    if (activeKind == StructuredTextFormat.json) {
      final validJson = _canParseJson(trimmed);
      return _EditorContentStatus(
        kind: StructuredTextFormat.json,
        canFormat: validJson,
        highlightRanges: pairAnalysis.highlightRanges,
        message: pairAnalysis.message ?? (validJson ? null : 'JSON 结构未完成'),
      );
    }
    if (activeKind == StructuredTextFormat.yaml) {
      final validYaml = _canParseYaml(trimmed);
      return _EditorContentStatus(
        kind: StructuredTextFormat.yaml,
        // YAML 对缩进敏感，自动格式化会破坏用户正在编辑的结构
        canFormat: false,
        highlightRanges: pairAnalysis.highlightRanges,
        message: pairAnalysis.message ?? (validYaml ? null : 'YAML 缩进或层级未完成'),
      );
    }
    if (activeKind == StructuredTextFormat.markdown) {
      return _EditorContentStatus(
        kind: StructuredTextFormat.markdown,
        canFormat: false,
        highlightRanges: pairAnalysis.highlightRanges,
        message: pairAnalysis.message,
      );
    }
    return _EditorContentStatus(
      kind: StructuredTextFormat.plain,
      canFormat: false,
      highlightRanges: pairAnalysis.highlightRanges,
      message: pairAnalysis.message,
    );
  }

  static String? format(String text, {required StructuredTextFormat format}) {
    final trimmed = text.trim();
    if (format == StructuredTextFormat.json) {
      try {
        return const JsonEncoder.withIndent('  ').convert(jsonDecode(trimmed));
      } catch (_) {}
    }
    if (format == StructuredTextFormat.yaml) {
      try {
        return json2yaml(_yamlToPlain(loadYaml(trimmed)));
      } catch (_) {}
    }
    return null;
  }

  static bool _looksLikeJson(String text) {
    return (text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'));
  }

  static bool _looksLikeYaml(String text) {
    return text.startsWith('---') ||
        text.contains(': ') ||
        text.contains(':\n') ||
        text.contains('\n- ');
  }

  static bool _looksLikeMarkdown(String text) {
    return RegExp(
          r'^(#{1,6}\s|\-\s|\*\s|\d+\.\s|>\s)',
          multiLine: true,
        ).hasMatch(text) ||
        text.contains('```') ||
        text.contains('**') ||
        text.contains('[](');
  }

  static bool _canParseJson(String text) {
    try {
      jsonDecode(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  static bool _canParseYaml(String text) {
    try {
      loadYaml(text);
      return true;
    } catch (_) {
      return false;
    }
  }

  static dynamic _yamlToPlain(dynamic input) {
    if (input is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        input.entries.map(
          (entry) => MapEntry('${entry.key}', _yamlToPlain(entry.value)),
        ),
      );
    }
    if (input is YamlList) {
      return input.map(_yamlToPlain).toList(growable: false);
    }
    return input;
  }

  static _PairAnalysis _analyzePairs(String text) {
    final stack = <_PairToken>[];
    final highlights = <TextRange>[];
    var inSingle = false;
    var inDouble = false;
    var singleStart = -1;
    var doubleStart = -1;
    var escaped = false;
    String? message;

    void addHighlight(int offset) {
      if (offset < 0 || offset >= text.length) {
        return;
      }
      final range = TextRange(start: offset, end: offset + 1);
      final alreadyExists = highlights.any(
        (existing) =>
            existing.start == range.start && existing.end == range.end,
      );
      if (!alreadyExists) {
        highlights.add(range);
      }
    }

    void note(String value) {
      message ??= value;
    }

    for (var index = 0; index < text.length; index += 1) {
      final char = String.fromCharCode(text.codeUnitAt(index));
      if (escaped) {
        escaped = false;
        continue;
      }
      if (char == r'\') {
        escaped = true;
        continue;
      }
      if (!inSingle && char == '"') {
        if (!inDouble) {
          doubleStart = index;
        } else {
          doubleStart = -1;
        }
        inDouble = !inDouble;
        continue;
      }
      if (!inDouble && char == "'") {
        if (!inSingle) {
          singleStart = index;
        } else {
          singleStart = -1;
        }
        inSingle = !inSingle;
        continue;
      }
      if (inSingle || inDouble) {
        continue;
      }
      if (char == '{' || char == '[' || char == '(') {
        stack.add(_PairToken(symbol: char, offset: index));
      } else if (char == '}' || char == ']' || char == ')') {
        if (stack.isEmpty) {
          addHighlight(index);
          note('右括号未配对');
          continue;
        }
        final last = stack.removeLast();
        if ((last.symbol == '{' && char != '}') ||
            (last.symbol == '[' && char != ']') ||
            (last.symbol == '(' && char != ')')) {
          addHighlight(last.offset);
          addHighlight(index);
          note('括号类型不匹配');
        }
      }
    }
    if (inSingle && singleStart >= 0) {
      addHighlight(singleStart);
      note('单引号未闭合');
    }
    if (inDouble && doubleStart >= 0) {
      addHighlight(doubleStart);
      note('双引号未闭合');
    }
    if (stack.isNotEmpty) {
      for (final token in stack) {
        addHighlight(token.offset);
      }
      note('括号未闭合');
    }
    highlights.sort((left, right) => left.start.compareTo(right.start));
    return _PairAnalysis(highlightRanges: highlights, message: message);
  }
}
