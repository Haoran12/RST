export interface LogEntry {
  id: string;
  chat_name: string;
  provider: string;
  model: string;
  status: string;
  request_time: string;
  response_time?: string | null;
  duration_ms?: number | null;
  prompt_tokens?: number | null;
  completion_tokens?: number | null;
  total_tokens?: number | null;
  stop_reason?: string | null;
  raw_request: unknown;
  raw_response: unknown;
}
