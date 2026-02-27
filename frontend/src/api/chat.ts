import apiClient from "@/api/client";
import type { ChatAttachment, ChatMessage } from "@/types/chat";

export interface MessageListResponse {
  messages: ChatMessage[];
  total: number;
}

export interface ChatRequest {
  content: string;
  attachments?: ChatAttachment[];
  message_id?: string;
}

export interface ChatResponse {
  user_message?: ChatMessage | null;
  assistant_message: ChatMessage;
}

export async function fetchMessages(sessionName: string): Promise<MessageListResponse> {
  const { data } = await apiClient.get<MessageListResponse>(
    `/sessions/${encodeURIComponent(sessionName)}/messages`,
  );
  return data;
}

export async function sendChatMessage(
  sessionName: string,
  payload: ChatRequest,
  options?: { signal?: AbortSignal; timeoutMs?: number },
): Promise<ChatResponse> {
  const { data } = await apiClient.post<ChatResponse>(
    `/sessions/${encodeURIComponent(sessionName)}/chat`,
    payload,
    {
      signal: options?.signal,
      // Chat completions can exceed the default API timeout, especially on "continue" sends.
      timeout: options?.timeoutMs ?? 120000,
    },
  );
  return data;
}

export async function updateMessage(
  sessionName: string,
  messageId: string,
  payload: { content?: string; visible?: boolean },
): Promise<ChatMessage> {
  const { data } = await apiClient.patch<ChatMessage>(
    `/sessions/${encodeURIComponent(sessionName)}/messages/${encodeURIComponent(messageId)}`,
    payload,
  );
  return data;
}

export async function deleteMessage(sessionName: string, messageId: string): Promise<void> {
  await apiClient.delete(
    `/sessions/${encodeURIComponent(sessionName)}/messages/${encodeURIComponent(messageId)}`,
  );
}
