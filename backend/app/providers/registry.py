from __future__ import annotations

from app.models.api_config import ProviderType
from app.providers.anthropic import AnthropicProvider
from app.providers.base import BaseProvider, ProviderError
from app.providers.deepseek import DeepseekProvider
from app.providers.gemini import GeminiProvider
from app.providers.openai import OpenAIProvider

_openai_provider = OpenAIProvider()
_gemini_provider = GeminiProvider()
_deepseek_provider = DeepseekProvider()
_anthropic_provider = AnthropicProvider()


def get_provider(provider_type: ProviderType) -> BaseProvider:
    """Return provider instance mapped to ProviderType."""
    mapping: dict[ProviderType, BaseProvider] = {
        ProviderType.OPENAI: _openai_provider,
        ProviderType.OPENAI_COMPAT: _openai_provider,
        ProviderType.DEEPSEEK: _deepseek_provider,
        ProviderType.GEMINI: _gemini_provider,
        ProviderType.ANTHROPIC: _anthropic_provider,
    }
    try:
        return mapping[provider_type]
    except KeyError as exc:
        raise ProviderError(f"Unknown provider: {provider_type}") from exc
