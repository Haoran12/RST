import '../bridge/frb_api.dart' as frb;
import '../bridge/rust_bridge.dart';
import '../models/common.dart';

class SessionService {
  const SessionService(this._rustBridge);

  final RustBridge _rustBridge;

  Future<void> loadWorkspace() async {
    await _rustBridge.listSessions();
  }

  Future<List<frb.SessionSummary>> listSessions() {
    return _rustBridge.listSessions();
  }

  Future<frb.SessionConfig> createSession({
    required String sessionName,
    required SessionMode mode,
    required String mainApiConfigId,
    required String presetId,
    String? stWorldBookId,
  }) {
    return _rustBridge.createSession(
      sessionName: sessionName,
      mode: mode,
      mainApiConfigId: mainApiConfigId,
      presetId: presetId,
      stWorldBookId: stWorldBookId,
    );
  }

  Future<frb.LoadSessionResult> loadSession(String sessionId) {
    return _rustBridge.loadSession(sessionId);
  }

  Future<frb.SessionConfig> saveSession(frb.SessionConfig config) {
    return _rustBridge.saveSession(config);
  }

  Future<frb.SessionConfig> renameSession({
    required String sessionId,
    required String sessionName,
  }) {
    return _rustBridge.renameSession(
      sessionId: sessionId,
      sessionName: sessionName,
    );
  }

  Future<frb.DeleteResult> deleteSession(String sessionId) {
    return _rustBridge.deleteSession(sessionId);
  }
}
