import 'dart:convert';

import 'package:dio/dio.dart';

import '../bridge/frb_api.dart' as frb;
import '../bridge/rust_bridge.dart';
import '../models/common.dart';
import '../models/provider_specs.dart';
import 'api_service.dart';
import 'provider_spec_service.dart';

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
  ChatService(this._rustBridge, this._providerSpecService, {Dio? dio})
    : _dio = dio ?? Dio();

  static const int _maxPreviewChars = 120000;
  static const int _maxRawSseChars = 60000;

  final RustBridge _rustBridge;
  final ProviderSpecService _providerSpecService;
  final Dio _dio;
  final Map<String, _ActiveStreamState> _activeStreams =
      <String, _ActiveStreamState>{};

  Future<List<frb.MessageRecord>> _loadLatestMessages(String sessionId) {
    return _rustBridge.listMessages(sessionId: sessionId);
  }

  Future<SendRoundResult> sendRound(SendRoundRequest request) async {
    final sessionId = request.sessionId.trim();
    final userInput = request.userInput.trim();
    if (sessionId.isEmpty) {
      throw ArgumentError.value(request.sessionId, 'sessionId');
    }

    final existingMessages = await _loadLatestMessages(sessionId);
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
      promptSourceMessages = await _loadLatestMessages(sessionId);
    }

    // Always refresh from storage before prompt assembly so visibility/content
    // changes made just before sending are reflected in this round.
    promptSourceMessages = await _loadLatestMessages(sessionId);

    final promptResult = await _buildPromptMessagesForSession(
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

    final providerSpec = await _providerSpecService.getSpec(
      request.apiConfig.providerType,
    );
    final providerRequest = _buildProviderRequest(
      apiConfig: request.apiConfig,
      providerSpec: providerSpec,
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
      requestUrl: _redactUrl(providerRequest.url),
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

    final allMessages = await _loadLatestMessages(sessionId);
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

    final latestMessages = await _loadLatestMessages(sessionId);
    final promptResult = _buildPromptMessagesForRetry(
      presetConfig: request.presetConfig,
      allMessages: latestMessages,
      userMessageId: retryPair.user.messageId,
      assistantMessageId: retryPair.assistant.messageId,
      maxContextMessages: request.maxContextMessages,
      userDescription: request.sessionUserDescription,
      scene: request.sessionScene,
      lores: request.sessionLores,
    );
    final providerSpec = await _providerSpecService.getSpec(
      request.apiConfig.providerType,
    );
    final providerRequest = _buildProviderRequest(
      apiConfig: request.apiConfig,
      providerSpec: providerSpec,
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
      requestUrl: _redactUrl(providerRequest.url),
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

      final response = await _dio.post<dynamic>(
        providerRequest.url,
        data: providerRequest.payload,
        cancelToken: active.cancelToken,
        options: Options(
          responseType: providerRequest.stream
              ? ResponseType.stream
              : ResponseType.json,
          headers: providerRequest.headers,
          connectTimeout: _durationFromMs(providerRequest.requestTimeoutMs),
          receiveTimeout: _durationFromMs(providerRequest.requestTimeoutMs),
          sendTimeout: _durationFromMs(providerRequest.requestTimeoutMs),
        ),
      );

      final consumeResult = providerRequest.stream
          ? await _consumeSseStream(
              body: response.data as ResponseBody,
              assistantMessageId: assistantMessageId,
              providerType: providerRequest.providerType,
              onMessageUpdated: onMessageUpdated,
            )
          : await _consumeJsonResponse(
              body: response.data,
              assistantMessageId: assistantMessageId,
              providerType: providerRequest.providerType,
              onMessageUpdated: onMessageUpdated,
            );
      final responseTime = DateTime.now().toUtc();
      final responsePreview = providerRequest.stream
          ? _buildSuccessResponsePreview(
              response: response,
              streamResult: consumeResult,
            )
          : _buildNonStreamSuccessResponsePreview(
              response: response,
              result: consumeResult,
            );
      await _persistRequestLog(
        sessionId: sessionId,
        provider: providerRequest.providerName,
        model: providerRequest.model,
        status: frb.RequestLogStatus.success,
        requestTime: requestTime,
        responseTime: responseTime,
        durationMs: responseTime.difference(requestTime).inMilliseconds,
        promptTokens: consumeResult.promptTokens,
        completionTokens: consumeResult.completionTokens,
        totalTokens: consumeResult.totalTokens,
        stopReason: consumeResult.stopReason,
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
      normalizedResponse: _redactSensitiveText(buffer.toString()),
      promptTokens: promptTokens,
      completionTokens: completionTokens,
      totalTokens: totalTokens,
      stopReason: stopReason,
    );
  }

  Future<_SseConsumeResult> _consumeJsonResponse({
    required Object? body,
    required String assistantMessageId,
    required ProviderType providerType,
    void Function(frb.MessageRecord message)? onMessageUpdated,
  }) async {
    if (body == null) {
      throw StateError('provider returned an empty response body');
    }
    final parsed = _parseJsonResponse(providerType: providerType, body: body);
    final updated = await _rustBridge.updateMessageContent(
      messageId: assistantMessageId,
      content: parsed.text,
    );
    onMessageUpdated?.call(updated);
    return _SseConsumeResult(
      rawSseLines: const <String>[],
      rawSseTruncated: false,
      normalizedResponse: _redactSensitiveText(parsed.text),
      promptTokens: parsed.promptTokens,
      completionTokens: parsed.completionTokens,
      totalTokens: parsed.totalTokens,
      stopReason: parsed.stopReason,
      responseBody: _normalizeResponseData(body),
    );
  }

  Future<_PromptResult> _buildPromptMessagesForSession({
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
    final sourceUser = allMessages.firstWhere(
      (m) => m.messageId == userMessageId,
    );
    return _assemblePromptMessages(
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
    required RuntimePresetConfig presetConfig,
    required List<frb.MessageRecord> historyMessages,
    required int maxContextMessages,
    required String requiredUserInput,
    required String userInputSource,
    required String userDescription,
    required String scene,
    required String lores,
  }) {
    final normalizedHistoryLimit = maxContextMessages < 0
        ? 0
        : maxContextMessages;
    var eligibleHistory = historyMessages;
    if (normalizedHistoryLimit > 0 &&
        eligibleHistory.length > normalizedHistoryLimit) {
      eligibleHistory = eligibleHistory
          .sublist(eligibleHistory.length - normalizedHistoryLimit)
          .toList(growable: false);
    }

    final promptMessages = <Map<String, String>>[];
    final usedEntries = <String>[];
    final context = _PromptContext(
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
    required ProviderSpec providerSpec,
    required List<Map<String, String>> promptMessages,
  }) {
    return switch (apiConfig.providerType) {
      ProviderType.openai => _buildOpenAiResponsesRequest(
        apiConfig: apiConfig,
        providerSpec: providerSpec,
        promptMessages: promptMessages,
      ),
      ProviderType.openaiCompatible => _buildCompatibleChatRequest(
        apiConfig: apiConfig,
        providerSpec: providerSpec,
        promptMessages: promptMessages,
        providerName: 'openai_compatible',
      ),
      ProviderType.deepseek => _buildCompatibleChatRequest(
        apiConfig: apiConfig,
        providerSpec: providerSpec,
        promptMessages: promptMessages,
        providerName: 'deepseek',
      ),
      ProviderType.openrouter => _buildCompatibleChatRequest(
        apiConfig: apiConfig,
        providerSpec: providerSpec,
        promptMessages: promptMessages,
        providerName: 'openrouter',
        extraHeaders: const <String, String>{
          'HTTP-Referer': 'https://sillytavern.app',
          'X-Title': 'SillyTavern',
        },
      ),
      ProviderType.anthropic => _buildAnthropicRequest(
        apiConfig: apiConfig,
        providerSpec: providerSpec,
        promptMessages: promptMessages,
      ),
      ProviderType.gemini => _buildGeminiRequest(
        apiConfig: apiConfig,
        providerSpec: providerSpec,
        promptMessages: promptMessages,
      ),
    };
  }

  void _applyConfiguredParameters({
    required Map<String, dynamic> payload,
    required RuntimeApiConfig apiConfig,
    required ProviderSpec providerSpec,
  }) {
    for (final parameter in providerSpec.parameters) {
      final value = _resolveConfiguredParameterValue(parameter, apiConfig);
      if (value == null) {
        continue;
      }
      _setNestedPayloadValue(payload, parameter.requestField, value);
    }
  }

  Object? _resolveConfiguredParameterValue(
    ProviderParameterSpec parameter,
    RuntimeApiConfig apiConfig,
  ) {
    final value = switch (parameter.key) {
      ApiParameterKey.stream => apiConfig.stream,
      ApiParameterKey.temperature => apiConfig.temperature,
      ApiParameterKey.topP => apiConfig.topP,
      ApiParameterKey.topK => apiConfig.topK,
      ApiParameterKey.presencePenalty => apiConfig.presencePenalty,
      ApiParameterKey.frequencyPenalty => apiConfig.frequencyPenalty,
      ApiParameterKey.maxCompletionTokens => apiConfig.maxCompletionTokens,
      ApiParameterKey.stopSequences => apiConfig.stopSequences,
      ApiParameterKey.reasoningEffort => apiConfig.reasoningEffort,
      ApiParameterKey.verbosity => apiConfig.verbosity,
    };

    if (value is List) {
      if (value.isEmpty) {
        return parameter.appFallbackValue;
      }
      return value;
    }
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isNotEmpty) {
        return normalized;
      }
      return parameter.appFallbackValue;
    }
    if (value is bool) {
      return value;
    }
    if (value is int) {
      if (value >= 0) {
        return value;
      }
      return parameter.appFallbackValue;
    }
    if (value is double) {
      return value;
    }
    return parameter.appFallbackValue;
  }

  void _setNestedPayloadValue(
    Map<String, dynamic> payload,
    String requestField,
    Object value,
  ) {
    final segments = requestField
        .split('.')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments.isEmpty) {
      return;
    }

    Map<String, dynamic> current = payload;
    for (var index = 0; index < segments.length - 1; index++) {
      final segment = segments[index];
      final next = current[segment];
      if (next is Map<String, dynamic>) {
        current = next;
        continue;
      }
      final nested = <String, dynamic>{};
      current[segment] = nested;
      current = nested;
    }
    current[segments.last] = value;
  }

  _ProviderRequest _buildOpenAiResponsesRequest({
    required RuntimeApiConfig apiConfig,
    required ProviderSpec providerSpec,
    required List<Map<String, String>> promptMessages,
  }) {
    final streamEnabled = apiConfig.stream ?? true;
    final payload = <String, dynamic>{
      'model': apiConfig.defaultModel,
      'stream': streamEnabled,
      'input': promptMessages
          .map(_toOpenAiInputMessage)
          .toList(growable: false),
    };
    _applyConfiguredParameters(
      payload: payload,
      apiConfig: apiConfig,
      providerSpec: providerSpec,
    );
    return _ProviderRequest(
      providerType: apiConfig.providerType,
      providerName: 'openai',
      model: apiConfig.defaultModel,
      url: _composeUrl(apiConfig.baseUrl, apiConfig.requestPath),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (apiConfig.apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer ${apiConfig.apiKey.trim()}',
        ...apiConfig.customHeaders,
      },
      payload: payload,
      stream: streamEnabled,
      requestTimeoutMs: apiConfig.requestTimeoutMs,
    );
  }

  _ProviderRequest _buildCompatibleChatRequest({
    required RuntimeApiConfig apiConfig,
    required ProviderSpec providerSpec,
    required List<Map<String, String>> promptMessages,
    required String providerName,
    Map<String, String> extraHeaders = const <String, String>{},
  }) {
    final streamEnabled = apiConfig.stream ?? true;
    final payload = <String, dynamic>{
      'model': apiConfig.defaultModel,
      'messages': promptMessages,
      'stream': streamEnabled,
    };
    _applyConfiguredParameters(
      payload: payload,
      apiConfig: apiConfig,
      providerSpec: providerSpec,
    );
    return _ProviderRequest(
      providerType: apiConfig.providerType,
      providerName: providerName,
      model: apiConfig.defaultModel,
      url: _composeUrl(apiConfig.baseUrl, apiConfig.requestPath),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (apiConfig.apiKey.trim().isNotEmpty)
          'Authorization': 'Bearer ${apiConfig.apiKey.trim()}',
        ...extraHeaders,
        ...apiConfig.customHeaders,
      },
      payload: payload,
      stream: streamEnabled,
      requestTimeoutMs: apiConfig.requestTimeoutMs,
    );
  }

  _ProviderRequest _buildAnthropicRequest({
    required RuntimeApiConfig apiConfig,
    required ProviderSpec providerSpec,
    required List<Map<String, String>> promptMessages,
  }) {
    final streamEnabled = apiConfig.stream ?? true;
    final systemChunks = <String>[];
    final messages = <Map<String, Object?>>[];
    for (final message in promptMessages) {
      final role = message['role'] ?? 'user';
      final content = (message['content'] ?? '').trim();
      if (content.isEmpty) {
        continue;
      }
      if (role == 'system') {
        systemChunks.add(content);
        continue;
      }
      messages.add(<String, Object?>{'role': role, 'content': content});
    }

    final payload = <String, dynamic>{
      'model': apiConfig.defaultModel,
      'messages': messages,
      'stream': streamEnabled,
    };
    if (systemChunks.isNotEmpty) {
      payload['system'] = systemChunks.join('\n\n');
    }
    _applyConfiguredParameters(
      payload: payload,
      apiConfig: apiConfig,
      providerSpec: providerSpec,
    );

    return _ProviderRequest(
      providerType: apiConfig.providerType,
      providerName: 'anthropic',
      model: apiConfig.defaultModel,
      url: _composeUrl(apiConfig.baseUrl, apiConfig.requestPath),
      headers: <String, String>{
        'Content-Type': 'application/json',
        if (apiConfig.apiKey.trim().isNotEmpty)
          'x-api-key': apiConfig.apiKey.trim(),
        'anthropic-version': '2023-06-01',
        ...apiConfig.customHeaders,
      },
      payload: payload,
      stream: streamEnabled,
      requestTimeoutMs: apiConfig.requestTimeoutMs,
    );
  }

  _ProviderRequest _buildGeminiRequest({
    required RuntimeApiConfig apiConfig,
    required ProviderSpec providerSpec,
    required List<Map<String, String>> promptMessages,
  }) {
    final streamEnabled = apiConfig.stream ?? true;
    final systemInstruction = <String>[];
    final contents = <Map<String, Object?>>[];
    for (final message in promptMessages) {
      final role = message['role'] ?? 'user';
      final content = (message['content'] ?? '').trim();
      if (content.isEmpty) {
        continue;
      }
      if (role == 'system') {
        systemInstruction.add(content);
        continue;
      }
      contents.add(<String, Object?>{
        'role': role == 'assistant' ? 'model' : 'user',
        'parts': <Map<String, String>>[
          <String, String>{'text': content},
        ],
      });
    }

    final payload = <String, dynamic>{
      'contents': contents,
      if (systemInstruction.isNotEmpty)
        'systemInstruction': <String, Object?>{
          'parts': <Map<String, String>>[
            <String, String>{'text': systemInstruction.join('\n\n')},
          ],
        },
    };
    _applyConfiguredParameters(
      payload: payload,
      apiConfig: apiConfig,
      providerSpec: providerSpec,
    );
    payload.remove('stream');

    return _ProviderRequest(
      providerType: apiConfig.providerType,
      providerName: 'gemini',
      model: apiConfig.defaultModel,
      url: _composeGeminiGenerateUrl(
        baseUrl: apiConfig.baseUrl,
        requestPath: apiConfig.requestPath,
        model: apiConfig.defaultModel,
        apiKey: apiConfig.apiKey,
        stream: streamEnabled,
      ),
      headers: <String, String>{
        'Content-Type': 'application/json',
        ...apiConfig.customHeaders,
      },
      payload: payload,
      stream: streamEnabled,
      requestTimeoutMs: apiConfig.requestTimeoutMs,
    );
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
    return _resolveRequestUri(
      baseUrl: baseUrl,
      requestPath: requestPath,
    ).toString();
  }

  String _composeGeminiGenerateUrl({
    required String baseUrl,
    required String requestPath,
    required String model,
    required String apiKey,
    required bool stream,
  }) {
    final normalizedPath = requestPath.trim().isEmpty
        ? ProviderType.gemini.defaultRequestPath
        : requestPath.trim();
    final method = stream ? 'streamGenerateContent' : 'generateContent';
    final endpointUri = _resolveRequestUri(
      baseUrl: baseUrl,
      requestPath: normalizedPath,
    );
    final uri = endpointUri.replace(
      pathSegments: <String>[
        ...endpointUri.pathSegments.where((segment) => segment.isNotEmpty),
        '$model:$method',
      ],
    );
    final queryParameters = <String, String>{
      ...uri.queryParameters,
      if (stream) 'alt': 'sse',
      if (apiKey.trim().isNotEmpty) 'key': apiKey.trim(),
    };
    return uri.replace(queryParameters: queryParameters).toString();
  }

  Uri _resolveRequestUri({
    required String baseUrl,
    required String requestPath,
  }) {
    final normalizedBase = baseUrl.trim();
    if (normalizedBase.isEmpty) {
      throw StateError('Base URL 不能为空');
    }
    final baseUri = Uri.tryParse(normalizedBase);
    if (baseUri == null || !baseUri.hasScheme || baseUri.host.isEmpty) {
      throw StateError('Base URL 不是合法地址: $baseUrl');
    }

    final normalizedRequestPath = requestPath.trim();
    if (normalizedRequestPath.isEmpty) {
      return baseUri.replace(pathSegments: _splitPathSegments(baseUri.path));
    }

    final absoluteRequestUri = _parseAbsoluteUriOrNull(normalizedRequestPath);
    if (absoluteRequestUri != null) {
      return absoluteRequestUri.replace(
        pathSegments: _splitPathSegments(absoluteRequestUri.path),
      );
    }

    final relativeRequestUri = Uri.tryParse(
      normalizedRequestPath.startsWith('/')
          ? normalizedRequestPath
          : '/$normalizedRequestPath',
    );
    if (relativeRequestUri == null) {
      throw StateError('Request Path 不是合法路径: $requestPath');
    }

    final mergedSegments = _mergePathSegments(
      _splitPathSegments(baseUri.path),
      _splitPathSegments(relativeRequestUri.path),
    );
    return baseUri.replace(
      pathSegments: mergedSegments,
      query: relativeRequestUri.hasQuery ? relativeRequestUri.query : null,
      fragment: relativeRequestUri.fragment.isNotEmpty
          ? relativeRequestUri.fragment
          : null,
    );
  }

  Uri? _parseAbsoluteUriOrNull(String raw) {
    final uri = Uri.tryParse(raw);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      return null;
    }
    return uri;
  }

  List<String> _splitPathSegments(String path) {
    return path
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
  }

  List<String> _mergePathSegments(
    List<String> baseSegments,
    List<String> requestSegments,
  ) {
    if (requestSegments.isEmpty) {
      return baseSegments;
    }
    var overlap = 0;
    final maxOverlap = baseSegments.length < requestSegments.length
        ? baseSegments.length
        : requestSegments.length;
    for (var size = maxOverlap; size > 0; size--) {
      final baseSlice = baseSegments.sublist(baseSegments.length - size);
      final requestSlice = requestSegments.sublist(0, size);
      var matched = true;
      for (var index = 0; index < size; index++) {
        if (baseSlice[index] != requestSlice[index]) {
          matched = false;
          break;
        }
      }
      if (matched) {
        overlap = size;
        break;
      }
    }
    return <String>[...baseSegments, ...requestSegments.sublist(overlap)];
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
      switch (providerType) {
        case ProviderType.openai:
          final openAiChunk = _parseOpenAiChunk(decoded);
          if (!openAiChunk.isEmpty) {
            return openAiChunk;
          }
        case ProviderType.anthropic:
          return _parseAnthropicChunk(decoded);
        case ProviderType.gemini:
          return _parseGeminiChunk(decoded);
        case ProviderType.openaiCompatible:
        case ProviderType.deepseek:
        case ProviderType.openrouter:
          break;
      }
      return _parseCompatibleChunk(decoded);
    } catch (_) {
      return const _SseChunk();
    }
  }

  _SseChunk _parseCompatibleChunk(Map<String, dynamic> decoded) {
    final choices = decoded['choices'];
    final firstChoice = choices is List && choices.isNotEmpty
        ? choices.first
        : null;
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

  _SseChunk _parseAnthropicChunk(Map<String, dynamic> decoded) {
    final type = decoded['type'];
    if (type is! String) {
      return const _SseChunk();
    }
    if (type == 'content_block_delta') {
      final delta = decoded['delta'];
      final deltaMap = delta is Map ? delta.cast<String, dynamic>() : null;
      if (deltaMap?['type'] == 'text_delta') {
        final text = deltaMap?['text'];
        return _SseChunk(deltaText: text is String ? text : '');
      }
    }
    if (type == 'message_start') {
      final message = decoded['message'];
      final messageMap = message is Map
          ? message.cast<String, dynamic>()
          : null;
      final usage = messageMap?['usage'];
      final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
      return _SseChunk(promptTokens: _asInt(usageMap?['input_tokens']));
    }
    if (type == 'message_delta') {
      final delta = decoded['delta'];
      final deltaMap = delta is Map ? delta.cast<String, dynamic>() : null;
      final usage = decoded['usage'];
      final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
      return _SseChunk(
        completionTokens: _asInt(usageMap?['output_tokens']),
        stopReason: '${deltaMap?['stop_reason'] ?? ''}'.trim().isEmpty
            ? null
            : '${deltaMap?['stop_reason']}',
      );
    }
    if (type == 'message_stop') {
      return const _SseChunk(stopReason: 'message_stop');
    }
    if (type == 'error') {
      return const _SseChunk(stopReason: 'error');
    }
    return const _SseChunk();
  }

  _SseChunk _parseGeminiChunk(Map<String, dynamic> decoded) {
    final candidates = decoded['candidates'];
    final firstCandidate = candidates is List && candidates.isNotEmpty
        ? candidates.first
        : null;
    final candidateMap = firstCandidate is Map
        ? firstCandidate.cast<String, dynamic>()
        : null;
    final content = candidateMap?['content'];
    final contentMap = content is Map ? content.cast<String, dynamic>() : null;
    final parts = contentMap?['parts'];
    final deltaText = parts is List
        ? parts.whereType<Map>().map((part) => '${part['text'] ?? ''}').join()
        : '';
    final usage = decoded['usageMetadata'];
    final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
    final promptTokens = _asInt(usageMap?['promptTokenCount']);
    final completionTokens = _asInt(usageMap?['candidatesTokenCount']);
    final totalTokens = _asInt(usageMap?['totalTokenCount']);
    final finishReason = candidateMap?['finishReason'];
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

  _ParsedResponseBody _parseJsonResponse({
    required ProviderType providerType,
    required Object? body,
  }) {
    final decoded = body is Map<String, dynamic>
        ? body
        : body is Map
        ? body.cast<String, dynamic>()
        : _decodeJsonMap(body);
    return switch (providerType) {
      ProviderType.openai => _parseOpenAiJsonResponse(decoded),
      ProviderType.anthropic => _parseAnthropicJsonResponse(decoded),
      ProviderType.gemini => _parseGeminiJsonResponse(decoded),
      ProviderType.openaiCompatible ||
      ProviderType.deepseek ||
      ProviderType.openrouter => _parseCompatibleJsonResponse(decoded),
    };
  }

  Map<String, dynamic> _decodeJsonMap(Object? body) {
    if (body is String) {
      final decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return decoded.cast<String, dynamic>();
      }
    }
    throw StateError('provider returned a non-JSON response body');
  }

  _ParsedResponseBody _parseCompatibleJsonResponse(
    Map<String, dynamic> decoded,
  ) {
    final choices = decoded['choices'];
    final firstChoice = choices is List && choices.isNotEmpty
        ? choices.first
        : null;
    final choiceMap = firstChoice is Map
        ? firstChoice.cast<String, dynamic>()
        : const <String, dynamic>{};
    final message = choiceMap['message'];
    final messageMap = message is Map
        ? message.cast<String, dynamic>()
        : const <String, dynamic>{};
    final text = _extractDeltaContent(messageMap['content']);
    final usage = decoded['usage'];
    final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
    return _ParsedResponseBody(
      text: text,
      promptTokens: _asInt(usageMap?['prompt_tokens']),
      completionTokens: _asInt(usageMap?['completion_tokens']),
      totalTokens: _asInt(usageMap?['total_tokens']),
      stopReason: '${choiceMap['finish_reason'] ?? ''}'.trim().isEmpty
          ? null
          : '${choiceMap['finish_reason']}',
    );
  }

  _ParsedResponseBody _parseAnthropicJsonResponse(
    Map<String, dynamic> decoded,
  ) {
    final content = decoded['content'];
    var text = '';
    if (content is List) {
      text = content
          .whereType<Map>()
          .map((item) => item['text'])
          .whereType<String>()
          .join();
    }
    final usage = decoded['usage'];
    final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
    return _ParsedResponseBody(
      text: text,
      promptTokens: _asInt(usageMap?['input_tokens']),
      completionTokens: _asInt(usageMap?['output_tokens']),
      totalTokens: _combineTokens(
        _asInt(usageMap?['input_tokens']),
        _asInt(usageMap?['output_tokens']),
      ),
      stopReason: '${decoded['stop_reason'] ?? ''}'.trim().isEmpty
          ? null
          : '${decoded['stop_reason']}',
    );
  }

  _ParsedResponseBody _parseGeminiJsonResponse(Map<String, dynamic> decoded) {
    final chunk = _parseGeminiChunk(decoded);
    return _ParsedResponseBody(
      text: chunk.deltaText,
      promptTokens: chunk.promptTokens,
      completionTokens: chunk.completionTokens,
      totalTokens: chunk.totalTokens,
      stopReason: chunk.stopReason,
    );
  }

  _ParsedResponseBody _parseOpenAiJsonResponse(Map<String, dynamic> decoded) {
    final outputText = '${decoded['output_text'] ?? ''}';
    if (outputText.trim().isNotEmpty) {
      final usage = decoded['usage'];
      final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
      return _ParsedResponseBody(
        text: outputText,
        promptTokens: _asInt(usageMap?['input_tokens']),
        completionTokens: _asInt(usageMap?['output_tokens']),
        totalTokens: _asInt(usageMap?['total_tokens']),
        stopReason: '${decoded['status'] ?? ''}'.trim().isEmpty
            ? null
            : '${decoded['status']}',
      );
    }

    final output = decoded['output'];
    if (output is List) {
      final text = output
          .whereType<Map>()
          .expand(
            (item) =>
                (item['content'] is List ? item['content'] as List : const [])
                    .whereType<Map>()
                    .map((part) => '${part['text'] ?? ''}'),
          )
          .join();
      final usage = decoded['usage'];
      final usageMap = usage is Map ? usage.cast<String, dynamic>() : null;
      return _ParsedResponseBody(
        text: text,
        promptTokens: _asInt(usageMap?['input_tokens']),
        completionTokens: _asInt(usageMap?['output_tokens']),
        totalTokens: _asInt(usageMap?['total_tokens']),
        stopReason: '${decoded['status'] ?? ''}'.trim().isEmpty
            ? null
            : '${decoded['status']}',
      );
    }
    return const _ParsedResponseBody(text: '');
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
      'url': _redactUrl(url),
      'headers': _redactHeaders(headers),
      'body': _redactJsonValue(payload),
    });
  }

  _PreviewData _buildSuccessResponsePreview({
    required Response<dynamic> response,
    required _SseConsumeResult streamResult,
  }) {
    return _encodePreviewJson(<String, Object?>{
      'status_code': response.statusCode,
      'headers': _redactHeaders(_flattenHeaders(response.headers)),
      'normalized_response': streamResult.normalizedResponse,
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

  _PreviewData _buildNonStreamSuccessResponsePreview({
    required Response<dynamic> response,
    required _SseConsumeResult result,
  }) {
    return _encodePreviewJson(<String, Object?>{
      'status_code': response.statusCode,
      'headers': _redactHeaders(_flattenHeaders(response.headers)),
      'normalized_response': result.normalizedResponse,
      'body': result.responseBody,
      if (result.stopReason != null) 'stop_reason': result.stopReason,
      if (result.promptTokens != null ||
          result.completionTokens != null ||
          result.totalTokens != null)
        'usage': <String, Object?>{
          'prompt_tokens': result.promptTokens,
          'completion_tokens': result.completionTokens,
          'total_tokens': result.totalTokens,
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

  String _redactUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.queryParameters.isEmpty) {
      return _redactSensitiveText(value);
    }
    final redacted = <String, String>{};
    for (final entry in uri.queryParameters.entries) {
      if (_isSensitiveKey(entry.key)) {
        redacted[entry.key] = '[REDACTED]';
      } else {
        redacted[entry.key] = _redactSensitiveText(entry.value);
      }
    }
    return uri.replace(queryParameters: redacted).toString();
  }

  Duration? _durationFromMs(int? timeoutMs) {
    if (timeoutMs == null || timeoutMs <= 0) {
      return null;
    }
    return Duration(milliseconds: timeoutMs);
  }

  String _readableError(DioException error) {
    final statusCode = error.response?.statusCode;
    final data = error.response?.data;
    final details = data == null ? '' : _redactSensitiveText(data.toString());
    if (statusCode == null) {
      final message = error.message == null
          ? null
          : _redactSensitiveText(error.message!);
      if (details.isNotEmpty) {
        return details;
      }
      final normalized = (message ?? '').toLowerCase();
      if (normalized.contains('failed host lookup')) {
        return 'network_dns_error: 无法解析目标域名。请检查 Base URL、设备网络/DNS、代理设置；Android release 包也要确认主清单包含 INTERNET 权限。原始错误: ${message ?? 'failed host lookup'}';
      }
      if (normalized.contains('connection timed out') ||
          normalized.contains('timed out')) {
        return 'network_timeout: 请求超时，请检查网络质量或增大请求超时。原始错误: ${message ?? 'timed out'}';
      }
      return message ?? 'network_error';
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
    required this.userInput,
    required this.historyMessages,
    required this.userDescription,
    required this.scene,
    required this.lores,
  });

  final String userInput;
  final List<frb.MessageRecord> historyMessages;
  final String userDescription;
  final String scene;
  final String lores;

  String mainPromptContent(String entryContent) => entryContent.trim();

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
    required this.stream,
    this.requestTimeoutMs,
  });

  final ProviderType providerType;
  final String providerName;
  final String model;
  final String url;
  final Map<String, String> headers;
  final Map<String, dynamic> payload;
  final bool stream;
  final int? requestTimeoutMs;
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
    required this.normalizedResponse,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.stopReason,
    this.responseBody,
  });

  final List<String> rawSseLines;
  final bool rawSseTruncated;
  final String normalizedResponse;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final String? stopReason;
  final Object? responseBody;
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

  bool get isEmpty =>
      deltaText.isEmpty &&
      promptTokens == null &&
      completionTokens == null &&
      totalTokens == null &&
      stopReason == null;
}

class _ParsedResponseBody {
  const _ParsedResponseBody({
    required this.text,
    this.promptTokens,
    this.completionTokens,
    this.totalTokens,
    this.stopReason,
  });

  final String text;
  final int? promptTokens;
  final int? completionTokens;
  final int? totalTokens;
  final String? stopReason;
}
