export type MessageRole = "system" | "user" | "assistant";

export interface ChatAttachment {
  name: string;
  size: number;
  type: string;
  content?: string;
}

export interface ChatMessage {
  id: string;
  role: MessageRole;
  content: string;
  timestamp: string;
  visible: boolean;
  attachments?: ChatAttachment[];
}
