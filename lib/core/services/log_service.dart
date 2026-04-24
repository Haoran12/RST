import '../bridge/frb_api.dart' as frb;
import '../bridge/rust_bridge.dart';
import 'runtime_log_service.dart';

class LogService {
  const LogService(this._rustBridge, this._runtimeLogService);

  final RustBridge _rustBridge;
  final RuntimeLogService _runtimeLogService;

  Future<List<frb.RequestLogSummary>> loadRecentLogs({
    String? sessionId,
    frb.RequestLogStatus? status,
    int limit = 50,
  }) {
    return _rustBridge.listRequestLogs(
      sessionId: sessionId,
      status: status,
      limit: limit,
    );
  }

  Future<frb.RequestLog> getLogDetail(String logId) {
    return _rustBridge.getRequestLog(logId);
  }

  Future<List<RuntimeLogEntry>> loadRecentRuntimeLogs({int limit = 200}) {
    return _runtimeLogService.readRecentEntries(limit: limit);
  }

  Future<String?> runtimeLogDirectoryPath() {
    return _runtimeLogService.logDirectoryPath();
  }
}
