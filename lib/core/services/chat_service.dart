import 'dart:convert';

import 'package:dio/dio.dart';

import '../bridge/frb_api.dart' as frb;
import '../bridge/rust_bridge.dart';
import '../models/common.dart';
import 'api_service.dart';

class PromptAssemblyMetadata {
  const PromptAssemblyMetadata({
    required this.entryOrder,
    required this.historyExpansionCount,
    required this.finalMessageCount,
    required this.userInput,
    required this.userInputSource,
  });

  final List<String> entryOrder;
  final int historyExpansionCount;
  final int finalMessageCount;
  final String userInput;
  final String userInputSource;
}

class RoundTripMetadata {
  const RoundTripMetadata({
    required this.sessionId,
    required this.presetId,
    required this.presetName,
    required this.providerType,
    required this.model,
    required this.requestUrl,
    required this.prompt,
    required this.requestBodyPreview,
    required this.requestBodyTruncated,
  });

  final String sessionId;
  final String presetId;
  final String presetName;
  final ProviderType providerType;
  final String model;
  final String requestUrl;
  final PromptAssemblyMetadata prompt;
  final String requestBodyPreview;
  final bool requestBodyTruncated;
}

class SendRoundRequest {
  const SendRoundRequest({
    required this.sessionId,
    required this.userInput,
    required this.apiConfig,
    required this.presetConfig,
    this.maxContextMessages = 16,
    this.sessionUserDescription = '',
    this.sessionScene = '',
    this.sessionLores = '',
    this.onRoundPrepared,
    this.onMessageUpdated,
  });

  final String sessionId;
  final String userInput;
  final RuntimeApiConfig apiConfig;
  final RuntimePresetConfig presetConfig;
  final int maxContextMessages;
  final String sessionUserDescription;
  final String sessionScene;
  final String sessionLores;
  final void Function(RoundTripMetadata metadata)? onRoundPrepared;
  final void Function(frb.MessageRecord message)? onMessageUpdated;
}

class RetryRoundRequest {
  const RetryRoundRequest({
    required this.sessionId,
    required this.apiConfig,
    required this.presetConfig,
    this.maxContextMessages = 16,
    this.sessionUserDescription = '',
    this.sessionScene = '',
    this.sessionLores = '',
    this.assistantMessageId,
    this.onRoundPrepared,
    this.onMessageUpdated,
  });

  final String sessionId;
  final RuntimeApiConfig apiConfig;
  final RuntimePresetConfig presetConfig;
  final int maxContextMessages;
  final String sessionUserDescription;
  final String sessionScene;
  final String sessionLores;
  final String? assistantMessageId;
  final void Function(RoundTripMetadata metadata)? onRoundPrepared;
  final void Function(frb.MessageRecord message)? onMessageUpdated;
}

class SendRoundResult {
  const SendRoundResult({
    this.userMessage,
    required this.assistantMessage,
    required this.metadata,
  });

  final frb.MessageRecord? userMessage;
  final frb.MessageRecord assistantMessage;
  final RoundTripMetadata metadata;
}

class ChatService {
  ChatService(this._rustBridge, {Dio? dio}) : _dio = dio ?? Dio();

  static const int _maxPreviewChars = 120000;
  static const int _maxRawSseChars = 60000;

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

    final loadedSession = await _rustBridge.loadSession(sessionId);
    final existingMessages = await _rustBridge.listMessages(sessionId: sessionId);
    final resolvedInput = _resolveUserInput(
      rawUserInput: userInput,
      visibleMessages: existingMessages,
    );

    frb.MessageRecord? userMessage;
    List<frb.MessageRecord> promptSourceMessages = existingMessages;
    final excludedHistoryMessageIds = <String>{
      ...resolvedInput.excludedHistoryMessageIds,
    };
    if (resolvedInput.createUserMessage) {
      userMessage = await _rustBridge.createMessage(
        sessionId: sessionId,
        role: frb.MessageRole.user,
        content: resolvedInput.resolvedUserInput,
        visible: true,
        status: frb.MessageStatus.completed,
      );
      request.onMessageUpdated?.call(userMessage);
      excludedHistoryMessageIds.add(userMessage.messageId);
      promptSourceMessages = await _rustBridge.listMessages(sessionId: sessionId);
    }

    final promptResult = await _buildPromptMessagesForSession(
      sessionConfig: loadedSession.config,
      presetConfig: request.presetConfig,
      allMessages: promptSourceMessages,
      maxContextMessages: request.maxContextMessages,
      requiredUserInput: resolvedInput.resolvedUserInput,
      excludedHistoryMessageIds: excludedHistoryMessageIds,
      userInputSource: resolvedInput.source,
      userDescription: request.sessionUserDescription,
      scene: request.sessionScene,
      lores: request.sessionLores,
    );
    final assistantMessage = await _rustBridge.createMessage(
      sessionId: sessionId,
      role: frb.MessageRole.assistant,
      content: '',
      visible: true,
      status: frb.MessageStatus.pending,
    );
    request.onMessageUpdated?.call(assistantMessage);

    final providerRequest = _buildProviderRequest(
      apiConfig: request.apiConfig,
      presetConfig: request.presetConfig,
      promptMessages: promptResult.messages,
    );
    final requestBodyPreview = _encodePreviewJson(
      _redactJsonValue(providerRequest.payload),
    );
    final metadata = RoundTripMetadata(
      sessionId: sessionId,
      presetId: request.presetConfig.presetId,
      presetName: request.presetConfig.name,
      providerType: request.apiConfig.providerType,
      model: providerRequest.model,
      requestUrl: providerRequest.url,
      prompt: promptResult.metadata,
      requestBodyPreview: requestBodyPreview.value ?? '{}',
      requestBodyTruncated: requestBodyPreview.truncated,
    );
    request.onRoundPrepared?.call(metadata);

    final completedAssistant = await _streamAssistantResponse(
      sessionId: sessionId,
      assistantMessageId: assistantMessage.messageId,
      providerRequest: providerRequest,
      onMessageUpdated: request.onMessageUpdated,
    );

    return SendRoundResult(
      userMessage: userMessage,
      assistantMessage: completedAssistant,
      metadata: metadata,
    );
  }

  Future<SendRoundResult> retryRound(RetryRoundRequest request) async {
    final sessionId = request.sessionId.trim();
    if (sessionId.isEmpty) {
      throw ArgumentError.value(request.sessionId, 'sessionId');
    }

    final loadedSession = await _rustBridge.loadSession(sessionId);
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
    request.onMessageUpdated?.call(retryPair.assistant);

    final promptResult = _buildPromptMessagesForRetry(
      sessionConfig: loadedSession.config,
      presetConfig: request.presetConfig,
      allMessages: allMessages,
      userMessageId: retryPair.user.messageId,
      assistantMessageId: retryPair.assistant.messageId,
      maxContextMessages: request.maxContextMessages,
      userDescription: request.sessionUserDescription,
      scene: request.sessionScene,
      lores: request.sessionLores,
    );
    final providerRequest = _buildProviderRequest(
      apiConfig: request.apiConfig,
      presetConfig: request.presetConfig,
      promptMessages: promptResult.messages,
    );
    final requestBodyPreview = _encodePreviewJson(
      _redactJsonValue(providerRequest.payload),
    );
    final metadata = RoundTripMetadata(
      sessionId: sessionId,
      presetId: request.presetConfig.presetId,
      presetName: request.presetConfig.name,
      providerType: request.apiConfig.providerType,
      model: providerRequest.model,
      requestUrl: providerRequest.url,
      prompt: promptResult.metadata,
      requestBodyPreview: requestBodyPreview.value ?? '{}',
      requestBodyTruncated: requestBodyPreview.truncated,
    );
    request.onRoundPrepared?.call(metadata);

    final completedAssistant = await _streamAssistantResponse(
      sessionId: sessionId,
      assistantMessageId: retryPair.assistant.messageId,
      providerRequest: providerRequest,
      onMessageUpdated: request.onMessageUpdated,
    );

    return SendRoundResult(
      userMessage: retryPair.user,
      assistantMessage: completedAssistant,
      metadata: metadata,
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
    required _ProviderRequest providerRequest,
    void Function(frb.MessageRecord message)? onMessageUpdated,
  }) async {
    if (_activeStreams.containsKey(sessionId)) {
      throw StateError('session $sessionId already has an active stream');
    }

    final streamingMessage = await _rustBridge.setMessageStatus(
      messageId: assistantMessageId,
      status: frb.MessageStatus.streaming,
    );
    onMessageUpdated?.call(streamingMessage);

    final active = _ActiveStreamState(CancelToken());
    _activeStreams[sessionId] = active;
    final requestTime = DateTime.now().toUtc();
    _PreviewData requestPreview = const _PreviewData(
      value: null,
      truncated: false,
    );
    try {
      requestPreview = _buildRequestPreview(
        url: providerRequest.url,
        headers: providerRequest.headers,
        payload: providerRequest.payload,
      );

      final response = await _dio.post<ResponseBody>(
        providerRequest.url,
        data: providerRequest.payload,
        cancelToken: active.cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          headers: providerRequest.headers,
        ),
      );

      final body = response.data;
      if (body == null) {
        throw StateError('provider returned an empty stream body');
      }

      final streamResult = await _consumeSseStream(
        body: body,
        assistantMessageId: assistantMessageId,
        providerType: providerRequest.providerType,
        onMessageUpdated: onMessageUpdated,
      );
      final responseTime = DateTime.now().toUtc();
      final responsePreview = _buildSuccessResponsePreview(
        response: response,
        streamResult: streamResult,
      );
      await _persistRequestLog(
        sessionId: sessionId,
        provider: providerRequest.providerName,
        model: providerRequest.model,
        status: frb.RequestLogStatus.success,
        requestTime: requestTime,
        responseTime: responseTime,
        durationMs: responseTime.difference(requestTime).inMilliseconds,
        promptTokens: streamResult.promptTokens,
        completionTokens: streamResult.completionTokens,
        totalTokens: streamResult.totalTokens,
        stopReason: streamResult.stopReason,
        requestPreviewJson: requestPreview.value,
        responsePreviewJson: responsePreview.value,
        payloadTruncated: requestPreview.truncated || responsePreview.truncated,
      );

      final completed = await _rustBridge.setMessageStatus(
        messageId: assistantMessageId,
        status: frb.MessageStatus.completed,
      );
      onMessageUpdated?.call(completed);
      return completed;
    } on DioException catch (error) {
      if (CancelToken.isCancel(error) || active.stoppedByUser) {
        final responseTime = DateTime.now().toUtc();
        final responsePreview = _buildCanceledResponsePreview(error);
        await _persistRequestLog(
          sessionId: sessionId,
          provider: providerRequest.providerName,
          model: providerRequest.model,
          status: frb.RequestLogStatus.error,
          requestTime: requestTime,
          responseTime: responseTime,
          durationMs: responseTime.difference(requestTime).inMilliseconds,
          stopReason: active.stoppedByUser
              ? 'stopped_by_user'
              : 'request_canceled',
          requestPreviewJson: requestPreview.value,
          responsePreviewJson: responsePreview.value,
          payloadTruncated:
              requestPreview.truncated || responsePreview.truncated,
        );
        final completed = await _rustBridge.setMessageStatus(
          messageId: assistantMessageId,
          status: frb.MessageStatus.completed,
        );
        onMessageUpdated?.call(completed);
        return completed;
      }
      final message = _readableError(error);
      final errored = await _rustBridge.setMessageStatus(
        messageId: assistantMessageId,
        status: frb.MessageStatus.error,
        errorMessage: message,
      );
      onMessageUpdated?.call(errored);
      final responseTime = DateTime.now().toUtc();
      final responsePreview = _buildErrorResponsePreview(error);
      await _persistRequestLog(
        sessionId: sessionId,
        provider: providerRequest.providerName,
        model: providerRequest.model,
        status: frb.RequestLogStatus.error,
        requestTime: requestTime,
        responseTime: responseTime,
        durationMs: responseTime.difference(requestTime).inMilliseconds,
        stopReason: 'http_error',
        requestPreviewJson: requestPreview.value,
        responsePreviewJson: responsePreview.value,
        payloadTruncated: requestPreview.truncated || responsePreview.truncated,
      );
      rethrow;
    } catch (error) {
      final errored = await _rustBridge.setMessageStatus(
        messageId: assistantMessageId,
        status: frb.MessageStatus.error,
        errorMessage: error.toString(),
      );
      onMessageUpdated?.call(errored);
      final responseTime = DateTime.now().toUtc();
      final responsePreview = _encodePreviewJson(<String, Object?>{
        'error': _redactSensitiveText(error.toString()),
      });
      await _persistRequestLog(
        sessionId: sessionId,
        provider: providerRequest.providerName,
        model: providerRequest.model,
        status: frb.RequestLogStatus.error,
        requestTime: requestTime,
        responseTime: responseTime,
        durationMs: responseTime.difference(requestTime).inMilliseconds,
        stopReason: 'client_error',
        requestPreviewJson: requestPreview.value,
        responsePreviewJson: responsePreview.value,
        payloadTruncated: requestPreview.truncated || responsePreview.truncated,
      );
      rethrow;
    } finally {
      _activeStreams.remove(sessionId);
    }
  }

  Future<_SseConsumeResult> _consumeSseStream({
    required ResponseBody body,
    required String assistantMessageId,
    required ProviderType providerType,
    void Function(frb.MessageRecord message)? onMessageUpdated,
  }) async {
    final buffer = StringBuffer();
    final rawSseLines = <String>[];
    var sseChars = 0;
    var sseTruncated = false;
    int? promptTokens;
    int? completionTokens;
    int? totalTokens;
    String? stopReason;

    void addSseLine(String line) {
      if (sseTruncated || line.isEmpty) {
        return;
      }
      final nextChars = sseChars + line.length + 1;
      if (nextChars > _maxRawSseChars) {
        sseTruncated = true;
        return;
      }
      rawSseLines.add(line);
      sseChars = nextChars;
    }

    await for (final rawLine
        in body.stream
            .map((chunk) => chunk.toList(growable: false))
            .transform(utf8.decoder)
            .transform(const LineSplitter())) {
      final line = rawLine.trimRight();
      if (line.isEmpty) {
        continue;
      }
      addSseLine(rawLine);
      if (!line.startsWith('data:')) {
        continue;
      }

      final payload = line.substring(5).trim();
      if (payload == '[DONE]') {
        stopReason ??= 'done';
        break;
      }

      final parsedChunk = _parseSseChunk(
        payload: payload,
        providerType: providerType,
      );
      promptTokens = parsedChunk.promptTokens ?? promptTokens;
      completionTokens = parsedChunk.completionTokens ?? completionTokens;
      totalTokens = parsedChunk.totalTokens ?? totalTokens;
      stopReason = parsedChunk.stopReason ?? stopReason;

      if (parsedChunk.deltaText.isEmpty) {
        continue;
      }

      buffer.write(parsedChunk.deltaText);
      final updated = await _rustBridge.updateMessageContent(
        messageId: assistantMessageId,
        content: buffer.toString(),
      );
      onMessageUpdated?.call(updated);
    }

    return _SseConsumeResult(
      rawSseLines: rawSseLines,
      rawSseTruncated: sseTruncated,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      stopReason: stopReason,
    );
  }

  Future<_PromptResult> _buildPromptMessagesForSession({
    required frb.SessionConfig sessionConfig,
    required RuntimePresetConfig presetConfig,
    required List<frb.MessageRecord> allMessages,
    required int maxContextMessages,
    required String requiredUserInput,
    required Set<String> excludedHistoryMessageIds,
    required String userInputSource,
    required String userDescription,
    required String scene,
    required String lores,
  }) async {
    final history = allMessages
        .where(
          (message) =>
              _isPromptEligible(message) &&
              !excludedHistoryMessageIds.contains(message.messageId),
        )
        .toList(growable: false);
    return _assemblePromptMessages(
      sessionConfig: sessionConfig,
      presetConfig: presetConfig,
      historyMessages: history,
      maxContextMessages: maxContextMessages,
      requiredUserInput: requiredUserInput,
      userInputSource: userInputSource,
      userDescription: userDescription,
      scene: scene,
      lores: lores,
    );
  }

  _PromptResult _buildPromptMessagesForRetry({
    required frb.SessionConfig sessionConfig,
    required RuntimePresetConfig presetConfig,
    required List<frb.MessageRecord> allMessages,
    required String userMessageId,
    required String assistantMessageId,
    required int maxContextMessages,
    required String userDescription,
    required String scene,
    required String lores,
  }) {
    final records = <frb.MessageRecord>[];
    for (final message in allMessages) {
      if (message.messageId == assistantMessageId) {
        break;
      }
      if (!_isPromptEligible(message)) {
        continue;
      }
      if (message.messageId == userMessageId) {
        continue;
      }
      records.add(message);
    }
    final sourceUser = allMessages.firstWhere((m) => m.messageId == userMessageId);
    return _assemblePromptMessages(
      sessionConfig: sessionConfig,
      presetConfig: presetConfig,
      historyMessages: records,
      maxContextMessages: maxContextMessages,
      requiredUserInput: sourceUser.content,
      userInputSource: 'retry:user_message',
      userDescription: userDescription,
      scene: scene,
      lores: lores,
    );
  }

  _PromptResult _assemblePromptMessages({
    required frb.SessionConfig sessionConfig,
    required RuntimePresetConfig presetConfig,
    required List<frb.MessageRecord> historyMessages,
    required int maxContextMessages,
    required String requiredUserInput,
    required String userInputSource,
    required String userDescription,
    required String scene,
    required String lores,
  }) {
    final normalizedHistoryLimit = maxContextMessages < 0 ? 0 : maxContextMessages;
    var eligibleHistory = historyMessages;
    if (normalizedHistoryLimit > 0 && eligibleHistory.length > normalizedHistoryLimit) {
      eligibleHistory = eligibleHistory
          .sublist(eligibleHistory.length - normalizedHistoryLimit)
          .toList(growable: false);
    }

    final promptMessages = <Map<String, String>>[];
    final usedEntries = <String>[];
    final context = _PromptContext(
      sessionConfig: sessionConfig,
      userInput: requiredUserInput,
      historyMessages: eligibleHistory,
      userDescription: userDescription,
      scene: scene,
      lores: lores,
    );

    for (final entry in presetConfig.entries) {
      if (entry.disabled) {
        continue;
      }
      usedEntries.add(entry.name);
      switch (entry.name) {
        case PresetBuiltinEntryNames.mainPrompt:
          _appendMessage(
            target: promptMessages,
            role: entry.role,
            content: context.mainPromptContent(entry.content),
          );
          break;
        case PresetBuiltinEntryNames.lores:
          _appendMessage(
            target: promptMessages,
            role: entry.role,
            content: context.loresContent(),
          );
          break;
        case PresetBuiltinEntryNames.userDescription:
          _appendMessage(
            target: promptMessages,
            role: entry.role,
            content: context.userDescriptionContent(),
          );
          break;
        case PresetBuiltinEntryNames.chatHistory:
          promptMessages.addAll(_toWireMessages(context.historyMessages));
          break;
        case PresetBuiltinEntryNames.scene:
          _appendMessage(
            target: promptMessages,
            role: entry.role,
            content: context.sceneContent(),
          );
          break;
        case PresetBuiltinEntryNames.userInput:
          _appendMessage(
            target: promptMessages,
            role: 'user',
            content: context.userInput,
          );
          break;
        default:
          _appendMessage(
            target: promptMessages,
            role: entry.role,
            content: entry.content,
          );
          break;
      }
    }

    return _PromptResult(
      messages: promptMessages,
      metadata: PromptAssemblyMetadata(
        entryOrder: usedEntries,
        historyExpansionCount: eligibleHistory.length,
        finalMessageCount: promptMessages.length,
        userInput: requiredUserInput,
        userInputSource: userInputSource,
      ),
    );
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

  _ResolvedUserInput _resolveUserInput({
    required String rawUserInput,
    required List<frb.MessageRecord> visibleMessages,
  }) {
    final normalized = rawUserInput.trim();
    if (normalized.isNotEmpty) {
      return _ResolvedUserInput(
        resolvedUserInput: normalized,
        source: 'typed',
        createUserMessage: true,
        excludedHistoryMessageIds: <String>{},
      );
    }

    for (var i = visibleMessages.length - 1; i >= 0; i -= 1) {
      final message = visibleMessages[i];
      if (!message.visible || message.status != frb.MessageStatus.completed) {
        continue;
      }
      if (message.role == frb.MessageRole.user) {
        return _ResolvedUserInput(
          resolvedUserInput: message.content,
          source: 'empty:latest_user_visible',
          createUserMessage: false,
          excludedHistoryMessageIds: <String>{message.messageId},
        );
      }
      break;
    }

    return const _ResolvedUserInput(
      resolvedUserInput: 'continue',
      source: 'empty:fallback_continue',
      createUserMessage: false,
      excludedHistoryMessageIds: <String>{},
    );
  }

  void _appendMessage({
    required List<Map<String, String>> target,
    required String role,
    required String content,
  }) {
    final normalizedContent = content.trim();
    if (normalizedContent.isEmpty) {
      return;
    }
    target.add(<String, String>{
      'role': _normalizeWireRole(role),
      'content': normalizedContent,
    });
  }

  String _normalizeWireRole(String role) {
    return switch (role.trim().toLowerCase()) {
      'user' => 'user',
      'assistant' => 'assistant',
      _ => 'system',
    };
  }

  _ProviderRequest _buildProviderRequest({
    required RuntimeApiConfig apiConfig,
    required RuntimePresetConfig presetConfig,
    required List<Map<String, String>> promptMessages,
  }) {
    final url = _composeUrl(apiConfig.baseUrl, apiConfig.requestPath);
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (apiConfig.apiKey.trim().isNotEmpty)
        'Authorization': 'Bearer ${apiConfig.apiKey.trim()}',
      ...apiConfig.customHeaders,
    };

    final payload = <String, dynamic>{
      'model': apiConfig.defaultModel,
      'stream': true,
    };
    _applyCommonGenerationParams(payload, presetConfig);
    final limit = presetConfig.maxCompletionTokens;

    if (apiConfig.providerType == ProviderType.openaiCompatible) {
      if (limit != null && limit > 0) {
        payload['max_tokens'] = limit;
      }
      payload['messages'] = promptMessages;
      return _ProviderRequest(
        providerType: apiConfig.providerType,
        providerName: 'openai_compatible',
        model: apiConfig.defaultModel,
        url: url,
        headers: headers,
        payload: payload,
      );
    }

    payload['input'] = promptMessages.map(_toOpenAiInputMessage).toList(growable: false);
    if (limit != null && limit > 0) {
      payload['max_output_tokens'] = limit;
    }
    if (presetConfig.reasoningEffort != null) {
      payload['reasoning'] = <String, Object?>{
        'effort': presetConfig.reasoningEffort,
      };
    }
    if (presetConfig.verbosity != null) {
      payload['text'] = <String, Object?>{'verbosity': presetConfig.verbosity};
    }

    return _ProviderRequest(
      providerType: apiConfig.providerType,
      providerName: 'openai',
      model: apiConfig.defaultModel,
      url: url,
      headers: headers,
      payload: payload,
    );
  }

  void _applyCommonGenerationParams(
    Map<String, dynamic> payload,
    RuntimePresetConfig presetConfig,
  ) {
    if (presetConfig.temperature != null) {
      payload['temperature'] = presetConfig.temperature;
    }
    if (presetConfig.topP != null) {
      payload['top_p'] = presetConfig.topP;
    }
    if (presetConfig.presencePenalty != null) {
      payload['presence_penalty'] = presetConfig.presencePenalty;
    }
    if (presetConfig.frequencyPenalty != null) {
      payload['frequency_penalty'] = presetConfig.frequencyPenalty;
    }

    if (presetConfig.stopSequences.isNotEmpty) {
      payload['stop'] = presetConfig.stopSequences;
    }
  }

  Map<String, Object?> _toOpenAiInputMessage(Map<String, String> message) {
    return <String, Object?>{
      'role': message['role'],
      'content': <Map<String, String>>[
        <String, String>{
          'type': 'input_text',
          'text': message['content'] ?? '',
        },
      ],
    };
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

  _SseChunk _parseSseChunk({
    required String payload,
    required ProviderType providerType,
  }) {
    try {
      final decoded = jsonDecode(payload);
      if (decoded is! Map<String, dynamic>) {
        return const _SseChunk();
      }
      if (providerType == ProviderType.openai) {
        return _parseOpenAiChunk(decoded);
      }
      return _parseCompatibleChunk(decoded);
    } catch (_) {
      return const _SseChunk();
    }
  }

  _SseChunk _parseCompatibleChunk(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    final firstChoice = choices is List && choices.isNotEmpty ? choices.first : null;
    final choiceMap = firstChoice is Map
        ? firstChoice.cast<String, dynamic>()
        : null;

    final delta = choiceMap?['delta'];
    final deltaMap = delta is Map ? delta.cast<String, dynamic>() : null;
    final content = deltaMap?['content'];
    final deltaText = _extractDeltaContent(content);

    final usage = decoded['usage'];
    final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
    final promptTokens = _asInt(usageMap?['prompt_tokens']);
    final completionTokens = _asInt(usageMap?['completion_tokens']);
    final totalTokens = _asInt(usageMap?['total_tokens']);

    final finishReason = choiceMap?['finish_reason'];
    return _SseChunk(
      deltaText: deltaText,
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      stopReason: finishReason is String && finishReason.isNotEmpty
          ? finishReason
          : null,
    );
  }

  _SseChunk _parseOpenAiChunk(Map<String, dynamic> decoded) {
    final eventType = decoded['type'];
    if (eventType is! String) {
      return const _SseChunk();
    }

    if (eventType == 'response.output_text.delta') {
      final delta = decoded['delta'];
      return _SseChunk(deltaText: delta is String ? delta : '');
    }

    if (eventType == 'response.completed') {
      final response = decoded['response'];
      final responseMap = response is Map
          ? response.cast<String, dynamic>()
          : null;
      final usage = responseMap?['usage'];
      final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
      final promptTokens = _asInt(usageMap?['input_tokens']);
      final completionTokens = _asInt(usageMap?['output_tokens']);
      final totalTokens = _asInt(usageMap?['total_tokens']);
      final status = responseMap?['status'];
      return _SseChunk(
        promptTokens: promptTokens,
        completionTokens: completionTokens,
        totalTokens: totalTokens,
        stopReason: status is String && status.isNotEmpty ? status : null,
      );
    }

    if (eventType == 'response.error') {
      final error = decoded['error'];
      final errorMap = error is Map ? error.cast<String, dynamic>() : null;
      final code = errorMap?['code'];
      return _SseChunk(
        stopReason: code is String && code.isNotEmpty ? code : 'response_error',
      );
    }

    return const _SseChunk();
  }

  String _extractDeltaContent(Object? content) {
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
  }

  int? _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return null;
  }

  _PreviewData _buildRequestPreview({
    required String url,
    required Map<String, String> headers,
    required Map<String, dynamic> payload,
  }) {
    return _encodePreviewJson(<String, Object?>{
      'method': 'POST',
      'url': url,
      'headers': _redactHeaders(headers),
      'body': _redactJsonValue(payload),
    });
  }

  _PreviewData _buildSuccessResponsePreview({
    required Response<ResponseBody> response,
    required _SseConsumeResult streamResult,
  }) {
    return _encodePreviewJson(<String, Object?>{
      'status_code': response.statusCode,
      'headers': _redactHeaders(_flattenHeaders(response.headers)),
      'stream': <String, Object?>{
        'lines': streamResult.rawSseLines,
        'truncated': streamResult.rawSseTruncated,
        if (streamResult.stopReason != null)
          'stop_reason': streamResult.stopReason,
        if (streamResult.promptTokens != null ||
            streamResult.completionTokens != null ||
            streamResult.totalTokens != null)
          'usage': <String, Object?>{
            'prompt_tokens': streamResult.promptTokens,
            'completion_tokens': streamResult.completionTokens,
            'total_tokens': streamResult.totalTokens,
          },
      },
    });
  }

  _PreviewData _buildErrorResponsePreview(DioException error) {
    return _encodePreviewJson(<String, Object?>{
      'status_code': error.response?.statusCode,
      'headers': _redactHeaders(_flattenHeaders(error.response?.headers)),
      'error_type': error.type.name,
      'error_message': _redactSensitiveText(error.message ?? 'dio_error'),
      'response_body': _normalizeResponseData(error.response?.data),
    });
  }

  _PreviewData _buildCanceledResponsePreview(DioException error) {
    return _encodePreviewJson(<String, Object?>{
      'error_type': error.type.name,
      'error_message': _redactSensitiveText(
        error.message ?? 'request_canceled',
      ),
    });
  }

  Map<String, String> _flattenHeaders(Headers? headers) {
    if (headers == null) {
      return const <String, String>{};
    }
    final result = <String, String>{};
    headers.map.forEach((key, values) {
      if (values.isEmpty) {
        return;
      }
      result[key] = values.join(', ');
    });
    return result;
  }

  Future<void> _persistRequestLog({
    required String sessionId,
    required String provider,
    required String model,
    required frb.RequestLogStatus status,
    required DateTime requestTime,
    required DateTime responseTime,
    required int durationMs,
    int? promptTokens,
    int? completionTokens,
    int? totalTokens,
    String? stopReason,
    String? requestPreviewJson,
    String? responsePreviewJson,
    required bool payloadTruncated,
  }) async {
    final mergedTotalTokens =
        totalTokens ?? _combineTokens(promptTokens, completionTokens);
    try {
      await _rustBridge.createRequestLog(
        seed: frb.CreateRequestLogRequest(
          sessionId: sessionId,
          provider: provider,
          model: model,
          status: status,
          requestTime: requestTime.toIso8601String(),
          responseTime: responseTime.toIso8601String(),
          durationMs: durationMs,
          promptTokens: promptTokens,
          completionTokens: completionTokens,
          totalTokens: mergedTotalTokens,
          stopReason: stopReason,
          redacted: true,
          payloadTruncated: payloadTruncated,
          requestPreviewJson: requestPreviewJson,
          responsePreviewJson: responsePreviewJson,
        ),
      );
    } catch (_) {
      // Do not break chat flow when log persistence fails.
    }
  }

  int? _combineTokens(int? promptTokens, int? completionTokens) {
    if (promptTokens == null || completionTokens == null) {
      return null;
    }
    return promptTokens + completionTokens;
  }

  _PreviewData _encodePreviewJson(Object? data) {
    final raw = const JsonEncoder.withIndent('  ').convert(data);
    if (raw.length <= _maxPreviewChars) {
      return _PreviewData(value: raw, truncated: false);
    }
    return _PreviewData(
      value: '${raw.substring(0, _maxPreviewChars)}\n...<truncated>',
      truncated: true,
    );
  }

  Map<String, String> _redactHeaders(Map<String, String> headers) {
    final sanitized = <String, String>{};
    headers.forEach((key, value) {
      if (_isSensitiveKey(key)) {
        sanitized[key] = '[REDACTED]';
      } else {
        sanitized[key] = _redactSensitiveText(value);
      }
    });
    return sanitized;
  }

  Object? _redactJsonValue(Object? value, {String? parentKey}) {
    if (value is Map) {
      final sanitized = <String, Object?>{};
      value.forEach((key, dynamic child) {
        final keyString = key.toString();
        if (_isSensitiveKey(keyString)) {
          sanitized[keyString] = '[REDACTED]';
        } else {
          sanitized[keyString] = _redactJsonValue(child, parentKey: keyString);
        }
      });
      return sanitized;
    }
    if (value is List) {
      return value
          .map((item) => _redactJsonValue(item, parentKey: parentKey))
          .toList(growable: false);
    }
    if (value is String) {
      if (parentKey != null && _isSensitiveKey(parentKey)) {
        return '[REDACTED]';
      }
      return _redactSensitiveText(value);
    }
    return value;
  }

  Object? _normalizeResponseData(Object? data) {
    if (data == null) {
      return null;
    }
    if (data is Map || data is List) {
      return _redactJsonValue(data);
    }
    if (data is String) {
      final trimmed = data.trim();
      if (trimmed.isEmpty) {
        return '';
      }
      try {
        final decoded = jsonDecode(trimmed);
        return _redactJsonValue(decoded);
      } catch (_) {
        return _redactSensitiveText(trimmed);
      }
    }
    return _redactSensitiveText(data.toString());
  }

  bool _isSensitiveKey(String key) {
    final normalized = key.toLowerCase();
    return normalized.contains('authorization') ||
        normalized.contains('api_key') ||
        normalized.contains('apikey') ||
        normalized.contains('x-api-key') ||
        normalized.contains('token') ||
        normalized.contains('secret') ||
        normalized.contains('password');
  }

  String _redactSensitiveText(String value) {
    var sanitized = value;
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'bearer\s+([^\s,;]+)', caseSensitive: false),
      (_) => 'Bearer [REDACTED]',
    );
    sanitized = sanitized.replaceAllMapped(
      RegExp(r'sk-[a-z0-9]{10,}', caseSensitive: false),
      (_) => 'sk-[REDACTED]',
    );
    return sanitized;
  }

  String _readableError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final details = data == null ? '' : _redactSensitiveText(data.toString());
    if (statusCode == null) {
      final message = error.message == null
          ? null
          : _redactSensitiveText(error.message!);
      return details.isEmpty ? message ?? 'network_error' : details;
    }
    if (details.isEmpty) {
      return 'http_$statusCode';
    }
    return 'http_$statusCode: $details';
  }
}

class _PromptResult {
  const _PromptResult({required this.messages, required this.metadata});

  final List<Map<String, String>> messages;
  final PromptAssemblyMetadata metadata;
}

class _PromptContext {
  const _PromptContext({
    required this.sessionConfig,
    required this.userInput,
    required this.historyMessages,
    required this.userDescription,
    required this.scene,
    required this.lores,
  });

  final frb.SessionConfig sessionConfig;
  final String userInput;
  final List<frb.MessageRecord> historyMessages;
  final String userDescription;
  final String scene;
  final String lores;

  String mainPromptContent(String entryContent) {
    final modeLabel = sessionConfig.mode == frb.SessionMode.rst ? 'RST' : 'ST';
    return [
      entryContent.trim(),
      'session_id: ${sessionConfig.sessionId}',
      'session_name: ${sessionConfig.sessionName}',
      'mode: $modeLabel',
    ].where((line) => line.isNotEmpty).join('\n');
  }

  String loresContent() => lores.trim();

  String userDescriptionContent() => userDescription.trim();

  String sceneContent() => scene.trim();
}

class _ResolvedUserInput {
  const _ResolvedUserInput({
    required this.resolvedUserInput,
    required this.source,
    required this.createUserMessage,
    required this.excludedHistoryMessageIds,
  });

  final String resolvedUserInput;
  final String source;
  final bool createUserMessage;
  final Set<String> excludedHistoryMessageIds;
}

class _ProviderRequest {
  const _ProviderRequest({
    required this.providerType,
    required this.providerName,
    required this.model,
    required this.url,
    required this.headers,
    required this.payload,
  });

  final ProviderType providerType;
  final String providerName;
  final String model;
  final String url;
  final Map<String, String> headers;
  final Map<String, dynamic> payload;
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

class _PreviewData {
  const _PreviewData({required this.value, required this.truncated});

  final String? value;
  final bool truncated;
}

class _SseConsumeResult {
  const _SseConsumeResult({
    required this.rawSseLines,
    required this.rawSseTruncated,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.stopReason,
  });

  final List<String> rawSseLines;
  final bool rawSseTruncated;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final String? stopReason;
}

class _SseChunk {
  const _SseChunk({
    this.deltaText = '',
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.stopReason,
  });

  final String deltaText;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final String? stopReason;
}
