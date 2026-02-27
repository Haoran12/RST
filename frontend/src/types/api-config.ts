export type ProviderType =
  | "openai"
  | "gemini"
  | "deepseek"
  | "anthropic"
  | "openai_compat";

export interface ApiConfigSummary {
  id: string;
  name: string;
  provider: ProviderType;
  model: string;
}

export interface ApiConfigDetail {
  id: string;
  name: string;
  provider: ProviderType;
  base_url: string;
  api_key_preview: string;
  model: string;
  temperature: number;
  max_tokens: number;
  stream: boolean;
}

export interface ApiConfigCreate {
  name: string;
  provider: ProviderType;
  base_url?: string;
  api_key: string;
  model?: string;
  temperature?: number;
  max_tokens?: number;
  stream?: boolean;
}

export interface ApiConfigUpdate {
  name?: string;
  provider?: ProviderType;
  base_url?: string;
  api_key?: string;
  model?: string;
  temperature?: number;
  max_tokens?: number;
  stream?: boolean;
}

export interface ModelListResponse {
  models: string[];
  error?: string;
}

export const DEFAULT_BASE_URLS: Record<ProviderType, string> = {
  openai: "https://api.openai.com/v1",
  gemini: "https://generativelanguage.googleapis.com/v1beta",
  deepseek: "https://api.deepseek.com/v1",
  anthropic: "https://api.anthropic.com/v1",
  openai_compat: "",
};
