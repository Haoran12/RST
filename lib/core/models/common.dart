enum ProviderType {
  openai,
  openaiCompatible,
  anthropic,
  gemini,
  deepseek,
  openrouter,
}

extension ProviderTypeX on ProviderType {
  String get wireValue {
    return switch (this) {
      ProviderType.openai => 'openai',
      ProviderType.openaiCompatible => 'openai_compatible',
      ProviderType.anthropic => 'anthropic',
      ProviderType.gemini => 'gemini',
      ProviderType.deepseek => 'deepseek',
      ProviderType.openrouter => 'openrouter',
    };
  }

  String get label {
    return switch (this) {
      ProviderType.openai => 'OpenAI',
      ProviderType.openaiCompatible => 'OpenAI-Compatible',
      ProviderType.anthropic => 'Anthropic',
      ProviderType.gemini => 'Google Gemini',
      ProviderType.deepseek => 'DeepSeek',
      ProviderType.openrouter => 'OpenRouter',
    };
  }

  String get shortDescription {
    return switch (this) {
      ProviderType.openai => '官方 Responses API',
      ProviderType.openaiCompatible => '标准 Chat Completions',
      ProviderType.anthropic => 'Claude Messages API',
      ProviderType.gemini => 'Google AI Studio 流式生成',
      ProviderType.deepseek => 'DeepSeek Chat Completions',
      ProviderType.openrouter => 'OpenRouter 聚合路由',
    };
  }

  String get defaultBaseUrl {
    return switch (this) {
      ProviderType.openai => 'https://api.openai.com',
      ProviderType.openaiCompatible => 'https://api.openai.com',
      ProviderType.anthropic => 'https://api.anthropic.com',
      ProviderType.gemini => 'https://generativelanguage.googleapis.com',
      ProviderType.deepseek => 'https://api.deepseek.com/beta',
      ProviderType.openrouter => 'https://openrouter.ai/api/v1',
    };
  }

  String get defaultRequestPath {
    return switch (this) {
      ProviderType.openai => '/v1/responses',
      ProviderType.openaiCompatible => '/v1/chat/completions',
      ProviderType.anthropic => '/v1/messages',
      ProviderType.gemini => '/v1beta/models',
      ProviderType.deepseek => '/chat/completions',
      ProviderType.openrouter => '/chat/completions',
    };
  }

  String get defaultModel {
    return switch (this) {
      ProviderType.openai => 'gpt-5.4-mini',
      ProviderType.openaiCompatible => 'gpt-4.1-mini',
      ProviderType.anthropic => 'claude-sonnet-4-5',
      ProviderType.gemini => 'gemini-2.5-pro',
      ProviderType.deepseek => 'deepseek-chat',
      ProviderType.openrouter => 'openai/gpt-4.1-mini',
    };
  }
}

ProviderType providerTypeFromWire(Object? raw) {
  final value = '$raw'.trim().toLowerCase();
  return switch (value) {
    'openai' => ProviderType.openai,
    'anthropic' => ProviderType.anthropic,
    'gemini' => ProviderType.gemini,
    'deepseek' => ProviderType.deepseek,
    'openrouter' => ProviderType.openrouter,
    'openai_compatible' || 'openai_compat' => ProviderType.openaiCompatible,
    _ => ProviderType.openaiCompatible,
  };
}

enum SessionMode { st, rst }
