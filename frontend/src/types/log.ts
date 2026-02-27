export interface LogEntry {
  id: string;
  chat_name: string;
  model: string;
  request_time: string;
  response_time?: string | null;
  raw_request: unknown;
  raw_response: unknown;
}
