import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';

import 'app.dart';
import 'core/services/runtime_log_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final runtimeLogs = RuntimeLogService.instance;
  await runtimeLogs.initialize();
  await runtimeLogs.info(
    category: 'app.lifecycle',
    message: 'startup',
    data: <String, Object?>{
      'platform': Platform.operatingSystem,
      'pid': pid,
    },
  );

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(
      runtimeLogs.fatal(
        category: 'app.crash',
        message: 'flutter_error',
        data: <String, Object?>{
          if (details.library != null) 'library': details.library,
          if (details.context != null)
            'context': details.context!.toDescription(),
        },
        error: details.exception,
        stackTrace: details.stack,
      ),
    );
  };

  WidgetsBinding.instance.platformDispatcher.onError = (error, stackTrace) {
    unawaited(
      runtimeLogs.fatal(
        category: 'app.crash',
        message: 'platform_dispatcher_error',
        error: error,
        stackTrace: stackTrace,
      ),
    );
    return false;
  };

  runZonedGuarded(
    () {
      runApp(
        const ProviderScope(
          child: _RuntimeLogLifecycleScope(child: RstApp()),
        ),
      );
    },
    (error, stackTrace) {
      unawaited(
        runtimeLogs.fatal(
          category: 'app.crash',
          message: 'zone_uncaught_error',
          error: error,
          stackTrace: stackTrace,
        ),
      );
    },
  );

  doWhenWindowReady(() {
    const initialSize = Size(1440, 900);
    const minSize = Size(800, 600);
    appWindow.minSize = minSize;
    appWindow.size = initialSize;
    appWindow.alignment = Alignment.center;
    appWindow.show();
    unawaited(
      runtimeLogs.info(
        category: 'app.window',
        message: 'window_ready',
        data: <String, Object?>{
          'width': initialSize.width,
          'height': initialSize.height,
        },
      ),
    );
  });
}

class _RuntimeLogLifecycleScope extends StatefulWidget {
  const _RuntimeLogLifecycleScope({required this.child});

  final Widget child;

  @override
  State<_RuntimeLogLifecycleScope> createState() =>
      _RuntimeLogLifecycleScopeState();
}

class _RuntimeLogLifecycleScopeState extends State<_RuntimeLogLifecycleScope>
    with WidgetsBindingObserver {
  final RuntimeLogService _runtimeLogs = RuntimeLogService.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _runtimeLogs.startHeartbeat();
    unawaited(
      _runtimeLogs.info(
        category: 'app.lifecycle',
        message: 'observer_attached',
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    unawaited(
      _runtimeLogs.info(
        category: 'app.lifecycle',
        message: 'state_changed',
        data: <String, Object?>{'state': state.name},
      ),
    );
  }

  @override
  void didHaveMemoryPressure() {
    super.didHaveMemoryPressure();
    unawaited(
      _runtimeLogs.warning(
        category: 'app.lifecycle',
        message: 'memory_pressure',
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _runtimeLogs.stopHeartbeat();
    unawaited(
      _runtimeLogs.info(
        category: 'app.lifecycle',
        message: 'observer_detached',
      ),
    );
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
