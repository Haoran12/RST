import '../bridge/frb_api.dart' as frb;
import '../bridge/rust_bridge.dart';

class LogService {
  const LogService(this._rustBridge);

  final RustBridge _rustBridge;

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
}
