import 'package:flutter/material.dart';

/// 自动保存 Mixin - 监听应用生命周期，在应用进入后台时自动保存
///
/// 使用方式：
/// ```dart
/// class _MyEditorState extends State<MyEditor> with AutoSaveMixin {
///   @override
///   bool get hasUnsavedChanges => _draft != _baseline;
///
///   @override
///   Future<void> performAutoSave() async {
///     if (!mounted) return;
///     await _save();
///   }
/// }
/// ```
mixin AutoSaveMixin<T extends StatefulWidget> on State<T>, WidgetsBindingObserver {
  /// 是否有未保存的更改
  bool get hasUnsavedChanges;

  /// 执行保存操作（异步，应安全处理 mounted 检查）
  Future<void> performAutoSave();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (hasUnsavedChanges) {
        performAutoSave();
      }
    }
  }
}
