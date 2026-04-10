import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bridge/rust_bridge.dart';
import '../services/api_service.dart';
import '../services/chat_service.dart';
import '../services/log_service.dart';
import '../services/session_service.dart';

final rustBridgeProvider = Provider<RustBridge>((_) => const RustBridge());
final apiServiceProvider = Provider<ApiService>((_) => const ApiService());
final sessionServiceProvider = Provider<SessionService>(
  (ref) => SessionService(ref.watch(rustBridgeProvider)),
);
final chatServiceProvider = Provider<ChatService>(
  (ref) => ChatService(ref.watch(rustBridgeProvider)),
);
final logServiceProvider = Provider<LogService>((_) => const LogService());
