import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../models/common.dart' as core;
import 'frb_api.dart' as frb;
import 'frb_generated.dart';

class RustBridge {
  const RustBridge();

  static bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }

    Directory supportDir;
    try {
      supportDir = await getApplicationSupportDirectory();
    } catch (_) {
      supportDir = Directory('${Directory.systemTemp.path}/rst_test_support');
      if (!supportDir.existsSync()) {
        supportDir.createSync(recursive: true);
      }
    }
    final workspaceDir = Directory('${supportDir.path}/rst_data');
    if (!workspaceDir.existsSync()) {
      workspaceDir.createSync(recursive: true);
    }

    await RustCore.init();
    await frb.setWorkspaceDir(path: workspaceDir.path);
    _initialized = true;
  }

  Future<List<frb.SessionSummary>> listSessions() async {
    await initialize();
    return frb.listSessions();
  }

  Future<frb.SessionConfig> createSession({
    required String sessionName,
    required core.SessionMode mode,
    required String mainApiConfigId,
    required String presetId,
    String? stWorldBookId,
  }) async {
    await initialize();
    return frb.createSession(
      seed: frb.CreateSessionRequest(
        sessionName: sessionName,
        mode: _toFrbSessionMode(mode),
        mainApiConfigId: mainApiConfigId,
        presetId: presetId,
        stWorldBookId: stWorldBookId,
      ),
    );
  }

  Future<frb.LoadSessionResult> loadSession(String sessionId) async {
    await initialize();
    return frb.loadSession(sessionId: sessionId);
  }

  Future<frb.SessionConfig> saveSession(frb.SessionConfig config) async {
    await initialize();
    return frb.saveSession(config: config);
  }

  Future<frb.SessionConfig> renameSession({
    required String sessionId,
    required String sessionName,
  }) async {
    await initialize();
    return frb.renameSession(sessionId: sessionId, sessionName: sessionName);
  }

  Future<frb.DeleteResult> deleteSession(String sessionId) async {
    await initialize();
    return frb.deleteSession(sessionId: sessionId);
  }

  Future<frb.MessageRecord> createMessage({
    required String sessionId,
    required frb.MessageRole role,
    required String content,
    required bool visible,
    required frb.MessageStatus status,
  }) async {
    await initialize();
    return frb.createMessage(
      message: frb.CreateMessageRequest(
        sessionId: sessionId,
        role: role,
        content: content,
        visible: visible,
        status: status,
      ),
    );
  }

  Future<frb.MessageRecord> updateMessageContent({
    required String messageId,
    required String content,
  }) async {
    await initialize();
    return frb.updateMessageContent(messageId: messageId, content: content);
  }

  Future<frb.MessageRecord> setMessageStatus({
    required String messageId,
    required frb.MessageStatus status,
    String? errorMessage,
  }) async {
    await initialize();
    return frb.setMessageStatus(
      messageId: messageId,
      status: status,
      errorMessage: errorMessage,
    );
  }

  Future<frb.MessageRecord> setMessageVisibility({
    required String messageId,
    required bool visible,
  }) async {
    await initialize();
    return frb.setMessageVisibility(messageId: messageId, visible: visible);
  }

  Future<frb.DeleteMessagesResult> deleteMessages({
    required String sessionId,
    required List<String> messageIds,
  }) async {
    await initialize();
    return frb.deleteMessages(sessionId: sessionId, messageIds: messageIds);
  }

  Future<List<frb.MessageRecord>> listMessages({
    required String sessionId,
    int? limit,
  }) async {
    await initialize();
    return frb.listMessages(sessionId: sessionId, limit: limit);
  }

  Future<frb.RequestLog> createRequestLog({
    required frb.CreateRequestLogRequest seed,
  }) async {
    await initialize();
    return frb.createRequestLog(seed: seed);
  }

  Future<List<frb.RequestLogSummary>> listRequestLogs({
    String? sessionId,
    frb.RequestLogStatus? status,
    int? limit,
  }) async {
    await initialize();
    return frb.listRequestLogs(
      sessionId: sessionId,
      status: status,
      limit: limit,
    );
  }

  Future<frb.RequestLog> getRequestLog(String logId) async {
    await initialize();
    return frb.getRequestLog(logId: logId);
  }

  frb.SessionMode _toFrbSessionMode(core.SessionMode mode) {
    return switch (mode) {
      core.SessionMode.st => frb.SessionMode.st,
      core.SessionMode.rst => frb.SessionMode.rst,
    };
  }
}
