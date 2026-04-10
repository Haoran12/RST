import 'dart:convert';

import 'package:dio/dio.dart';

import '../bridge/frb_api.dart' as frb;
import '../bridge/rust_bridge.dart';

class OpenAiCompatibleConfig {
  const OpenAiCompatibleConfig({
    required this.baseUrl,
    required this.apiKey,
    required this.model,
    this.requestPath = '/v1/chat/completions',
    this.temperature,
    this.topP,
    this.presencePenalty,
    this.frequencyPenalty,
    this.maxTokens,
    this.stopSequences = const <String>[],
    this.customHeaders = const <String, String>{},
  });

  final String baseUrl;
  final String apiKey;
  final String model;
  final String requestPath;
  final double? temperature;
  final double? topP;
  final double? presencePenalty;
  final double? frequencyPenalty;
  final int? maxTokens;
  final List<String> stopSequences;
  final Map<String, String> customHeaders;
}

class SendRoundRequest {
  const SendRoundRequest({
    required this.sessionId,
    required this.userInput,
    required this.provider,
  });

  final String sessionId;
  final String userInput;
  final OpenAiCompatibleConfig provider;
}

class RetryRoundRequest {
  const RetryRoundRequest({
    required this.sessionId,
    required this.provider,
    this.assistantMessageId,
  });

  final String sessionId;
  final OpenAiCompatibleConfig provider;
  final String? assistantMessageId;
}

class SendRoundResult {
  const SendRoundResult({
    required this.userMessage,
    required this.assistantMessage,
  });

  final frb.MessageRecord userMessage;
  final frb.MessageRecord assistantMessage;
}

class ChatService {
  ChatService(this._rustBridge, {Dio? dio}) : _dio = dio ?? Dio();

  final RustBridge _rustBridge;
  final Dio _dio;
  final Map<String, _ActiveStreamState> _activeStreams =
      <String, _ActiveStreamState>{};

  Future<SendRoundResult> sendRound(SendRoundRequest request) async {
    final sessionId = request.sessionId.trim();
    final userInput = request.userInput.trim();
    if (sessionId.isEmpty) {
      throw ArgumentError.value(request.sessionId, 'sessionId');
    }
    if (userInput.isEmpty) {
      throw ArgumentError.value(request.userInput, 'userInput');
    }

    await _rustBridge.loadSession(sessionId);

    final userMessage = await _rustBridge.createMessage(
      sessionId: sessionId,
      role: frb.MessageRole.user,
      content: userInput,
      visible: true,
      status: frb.MessageStatus.completed,
    );

    final promptMessages = await _buildPromptMessagesForSession(sessionId);
    final assistantMessage = await _rustBridge.createMessage(
      sessionId: sessionId,
      role: frb.MessageRole.assistant,
      content: '',
      visible: true,
      status: frb.MessageStatus.pending,
    );

    final completedAssistant = await _streamAssistantResponse(
      sessionId: sessionId,
      assistantMessageId: assistantMessage.messageId,
      provider: request.provider,
      promptMessages: promptMessages,
    );

    return SendRoundResult(
      userMessage: userMessage,
      assistantMessage: completedAssistant,
    );
  }

  Future<frb.MessageRecord> retryRound(RetryRoundRequest request) async {
    final sessionId = request.sessionId.trim();
    if (sessionId.isEmpty) {
      throw ArgumentError.value(request.sessionId, 'sessionId');
    }

    await _rustBridge.loadSession(sessionId);
    final allMessages = await _rustBridge.listMessages(sessionId: sessionId);
    final retryPair = _resolveRetryPair(
      allMessages: allMessages,
      explicitAssistantMessageId: request.assistantMessageId,
    );

    await _rustBridge.updateMessageContent(
      messageId: retryPair.assistant.messageId,
      content: '',
    );
    await _rustBridge.setMessageStatus(
      messageId: retryPair.assistant.messageId,
      status: frb.MessageStatus.pending,
    );

    final promptMessages = _buildPromptMessagesForRetry(
      allMessages: allMessages,
      userMessageId: retryPair.user.messageId,
      assistantMessageId: retryPair.assistant.messageId,
    );

    return _streamAssistantResponse(
      sessionId: sessionId,
      assistantMessageId: retryPair.assistant.messageId,
      provider: request.provider,
      promptMessages: promptMessages,
    );
  }

  Future<bool> stop(String sessionId) async {
    final state = _activeStreams[sessionId];
    if (state == null) {
      return false;
    }
    state.stoppedByUser = true;
    state.cancelToken.cancel('stopped_by_user');
    return true;
  }

  Future<frb.MessageRecord> _streamAssistantResponse({
    required String sessionId,
    required String assistantMessageId,
    required OpenAiCompatibleConfig provider,
    required List<Map<String, String>> promptMessages,
  }) async {
    if (_activeStreams.containsKey(sessionId)) {
      throw StateError('session $sessionId already has an active stream');
    }

    await _rustBridge.setMessageStatus(
      messageId: assistantMessageId,
      status: frb.MessageStatus.streaming,
    );

    final active = _ActiveStreamState(CancelToken());
    _activeStreams[sessionId] = active;
    try {
      final payload = <String, dynamic>{
        'model': provider.model,
        'messages': promptMessages,
        'stream': true,
        if (provider.maxTokens != null) 'max_tokens': provider.maxTokens,
        if (provider.temperature != null) 'temperature': provider.temperature,
        if (provider.topP != null) 'top_p': provider.topP,
        if (provider.presencePenalty != null)
          'presence_penalty': provider.presencePenalty,
        if (provider.frequencyPenalty != null)
          'frequency_penalty': provider.frequencyPenalty,
        if (provider.stopSequences.isNotEmpty) 'stop': provider.stopSequences,
      };

      final headers = <String, String>{
        'Content-Type': 'application/json',
        if (provider.apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer ${provider.apiKey.trim()}',
        ...provider.customHeaders,
      };

      final response = await _dio.post<ResponseBody>(
        _composeUrl(provider.baseUrl, provider.requestPath),
        data: payload,
        cancelToken: active.cancelToken,
        options: Options(responseType: ResponseType.stream, headers: headers),
      );

      final body = response.data;
      if (body == null) {
        throw StateError('provider returned an empty stream body');
      }

      await _consumeSseStream(
        body: body,
        assistantMessageId: assistantMessageId,
      );

      return _rustBridge.setMessageStatus(
        messageId: assistantMessageId,
        status: frb.MessageStatus.completed,
      );
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || active.stoppedByUser) {
        return _rustBridge.setMessageStatus(
          messageId: assistantMessageId,
          status: frb.MessageStatus.completed,
        );
      }
      final message = _readableError(error);
      await _rustBridge.setMessageStatus(
        messageId: assistantMessageId,
        status: frb.MessageStatus.error,
        errorMessage: message,
      );
      rethrow;
    } catch (error) {
      await _rustBridge.setMessageStatus(
        messageId: assistantMessageId,
        status: frb.MessageStatus.error,
        errorMessage: error.toString(),
      );
      rethrow;
    } finally {
      _activeStreams.remove(sessionId);
    }
  }

  Future<void> _consumeSseStream({
    required ResponseBody body,
    required String assistantMessageId,
  }) async {
    final buffer = StringBuffer();
    await for (final rawLine
        in body.stream
            .map((chunk) => chunk.toList(growable: false))
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final line = rawLine.trim();
      if (line.isEmpty || !line.startsWith('data:')) {
        continue;
      }

      final payload = line.substring(5).trim();
      if (payload == '[DONE]') {
        break;
      }

      final delta = _extractDeltaText(payload);
      if (delta.isEmpty) {
        continue;
      }

      buffer.write(delta);
      await _rustBridge.updateMessageContent(
        messageId: assistantMessageId,
        content: buffer.toString(),
      );
    }
  }

  Future<List<Map<String, String>>> _buildPromptMessagesForSession(
    String sessionId,
  ) async {
    final messages = await _rustBridge.listMessages(sessionId: sessionId);
    return _toWireMessages(messages.where(_isPromptEligible));
  }

  List<Map<String, String>> _buildPromptMessagesForRetry({
    required List<frb.MessageRecord> allMessages,
    required String userMessageId,
    required String assistantMessageId,
  }) {
    final records = <frb.MessageRecord>[];
    for (final message in allMessages) {
      if (message.messageId == assistantMessageId) {
        break;
      }
      if (!_isPromptEligible(message)) {
        continue;
      }
      records.add(message);
      if (message.messageId == userMessageId) {
        continue;
      }
    }
    return _toWireMessages(records);
  }

  _RetryPair _resolveRetryPair({
    required List<frb.MessageRecord> allMessages,
    String? explicitAssistantMessageId,
  }) {
    final assistantIndex = explicitAssistantMessageId == null
        ? allMessages.lastIndexWhere((m) => m.role == frb.MessageRole.assistant)
        : allMessages.indexWhere(
            (m) => m.messageId == explicitAssistantMessageId.trim(),
          );
    if (assistantIndex < 0 || assistantIndex >= allMessages.length) {
      throw StateError('assistant message for retry was not found');
    }

    final assistant = allMessages[assistantIndex];
    if (assistant.role != frb.MessageRole.assistant) {
      throw StateError('retry target must be an assistant message');
    }

    var userIndex = -1;
    for (var i = assistantIndex - 1; i >= 0; i -= 1) {
      if (allMessages[i].role == frb.MessageRole.user) {
        userIndex = i;
        break;
      }
    }

    if (userIndex < 0) {
      throw StateError('no source user message found for retry');
    }

    return _RetryPair(user: allMessages[userIndex], assistant: assistant);
  }

  List<Map<String, String>> _toWireMessages(
    Iterable<frb.MessageRecord> records,
  ) {
    final wire = <Map<String, String>>[];
    for (final record in records) {
      wire.add(<String, String>{
        'role': _wireRole(record.role),
        'content': record.content,
      });
    }
    return wire;
  }

  bool _isPromptEligible(frb.MessageRecord record) {
    return record.visible &&
        record.status == frb.MessageStatus.completed &&
        record.content.isNotEmpty;
  }

  String _wireRole(frb.MessageRole role) {
    return switch (role) {
      frb.MessageRole.system => 'system',
      frb.MessageRole.user => 'user',
      frb.MessageRole.assistant => 'assistant',
    };
  }

  String _composeUrl(String baseUrl, String requestPath) {
    final trimmedBase = baseUrl.trim().replaceFirst(RegExp(r'/+$'), '');
    if (requestPath.startsWith('http://') ||
        requestPath.startsWith('https://')) {
      return requestPath;
    }
    final normalizedPath = requestPath.startsWith('/')
        ? requestPath
        : '/$requestPath';
    return '$trimmedBase$normalizedPath';
  }

  String _extractDeltaText(String payload) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return '';
      }

      final choices = decoded['choices'];
      if (choices is! List || choices.isEmpty) {
        return '';
      }

      final first = choices.first;
      if (first is! Map<String, dynamic>) {
        return '';
      }

      final delta = first['delta'];
      if (delta is! Map<String, dynamic>) {
        return '';
      }

      final content = delta['content'];
      if (content is String) {
        return content;
      }

      if (content is List) {
        return content
            .whereType<Map>()
            .map((item) => item['text'])
            .whereType<String>()
            .join();
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  String _readableError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final details = data == null ? '' : data.toString();
    if (statusCode == null) {
      return details.isEmpty ? error.message ?? 'network_error' : details;
    }
    if (details.isEmpty) {
      return 'http_$statusCode';
    }
    return 'http_$statusCode: $details';
  }
}

class _RetryPair {
  const _RetryPair({required this.user, required this.assistant});

  final frb.MessageRecord user;
  final frb.MessageRecord assistant;
}

class _ActiveStreamState {
  _ActiveStreamState(this.cancelToken);

  final CancelToken cancelToken;
  bool stoppedByUser = false;
}
