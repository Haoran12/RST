import { defineStore } from "pinia";
import { computed, ref } from "vue";
import axios from "axios";

import { message } from "@/utils/message";
import { parseApiError } from "@/stores/api-error";
import {
  deleteMessage as deleteMessageApi,
  fetchMessages,
  sendChatMessage,
  updateMessage as updateMessageApi,
} from "@/api/chat";

import type { ChatAttachment, ChatMessage, MessageRole } from "@/types/chat";

export type BatchAction = "delete" | "hide" | null;

function generateId(): string {
  if (typeof crypto !== "undefined" && "randomUUID" in crypto) {
    return crypto.randomUUID();
  }
  return `msg_${Date.now()}_${Math.random().toString(16).slice(2)}`;
}

export const useChatStore = defineStore("chat", () => {
  const activeSession = ref<string | null>(null);
  const messagesBySession = ref<Record<string, ChatMessage[]>>({});
  const pendingAttachments = ref<ChatAttachment[]>([]);
  const batchAction = ref<BatchAction>(null);
  const selectedIds = ref<string[]>([]);
  const isSending = ref(false);
  const isRstDataUpdating = ref(false);
  const requestController = ref<AbortController | null>(null);

  const currentMessages = computed<ChatMessage[]>(() => {
    if (!activeSession.value) {
      return [];
    }
    return messagesBySession.value[activeSession.value] ?? [];
  });

  const hasActiveSession = computed(() => Boolean(activeSession.value));
  const hasMessages = computed(() => currentMessages.value.length > 0);
  const isBatchMode = computed(() => batchAction.value !== null);
  const hasRunningWork = computed(
    () => isSending.value || isRstDataUpdating.value,
  );

  function setMessages(name: string, messages: ChatMessage[]): void {
    messagesBySession.value = { ...messagesBySession.value, [name]: messages };
  }

  async function loadMessages(name: string): Promise<void> {
    if (!name) {
      return;
    }
    setMessages(name, messagesBySession.value[name] ?? []);
    try {
      const response = await fetchMessages(name);
      setMessages(name, response.messages);
    } catch (error) {
      message.error(parseApiError(error));
    }
  }

  function cancelSending(): void {
    if (!requestController.value) {
      return;
    }
    requestController.value.abort();
  }

  function cancelInFlightOperations(): void {
    cancelSending();
    isRstDataUpdating.value = false;
  }

  function clearSessionRuntime(name: string): void {
    if (!name) {
      return;
    }
    const next = { ...messagesBySession.value };
    delete next[name];
    messagesBySession.value = next;
    if (activeSession.value === name) {
      selectedIds.value = [];
      batchAction.value = null;
      pendingAttachments.value = [];
    }
  }

  function setActiveSession(name: string | null): void {
    if (name !== activeSession.value && hasRunningWork.value) {
      cancelInFlightOperations();
    }
    activeSession.value = name;
    selectedIds.value = [];
    batchAction.value = null;
    if (name) {
      void loadMessages(name);
    }
  }

  function addMessage(payload: {
    role: MessageRole;
    content: string;
    attachments?: ChatAttachment[];
  }): void {
    if (!activeSession.value) {
      message.error("Select a session first.");
      return;
    }
    const messageItem: ChatMessage = {
      id: generateId(),
      role: payload.role,
      content: payload.content,
      timestamp: new Date().toISOString(),
      visible: true,
      attachments: payload.attachments?.length ? payload.attachments : undefined,
    };
    const next = [...currentMessages.value, messageItem];
    setMessages(activeSession.value, next);
  }

  async function sendMessage(
    content: string,
    attachments?: ChatAttachment[],
  ): Promise<void> {
    if (!activeSession.value) {
      message.error("Select a session first.");
      return;
    }
    if (isSending.value) {
      return;
    }

    const sessionName = activeSession.value;
    const trimmed = content.trim();
    const hasExplicitInput = trimmed.length > 0 || Boolean(attachments?.length);
    let userMessage: ChatMessage | null = null;
    let next = [...(messagesBySession.value[sessionName] ?? [])];
    if (hasExplicitInput) {
      userMessage = {
        id: generateId(),
        role: "user",
        content: trimmed,
        timestamp: new Date().toISOString(),
        visible: true,
        attachments: attachments?.length ? attachments : undefined,
      };
      next = [...next, userMessage];
      setMessages(sessionName, next);
    }

    const controller = new AbortController();
    requestController.value = controller;
    isSending.value = true;
    isRstDataUpdating.value = true;

    try {
      const response = await sendChatMessage(
        sessionName,
        {
          content: trimmed,
          attachments,
          message_id: userMessage?.id,
        },
        { signal: controller.signal },
      );
      const assistantMessage = response.assistant_message;
      const current = messagesBySession.value[sessionName] ?? next;
      const hasAssistant = current.some((item) => item.id === assistantMessage.id);
      if (!hasAssistant) {
        setMessages(sessionName, [...current, assistantMessage]);
      }
    } catch (error) {
      if (axios.isAxiosError(error) && error.code === "ERR_CANCELED") {
        message.info("Request stopped.");
        return;
      }
      message.error(parseApiError(error));
    } finally {
      if (requestController.value === controller) {
        requestController.value = null;
      }
      isSending.value = false;
      isRstDataUpdating.value = false;
    }
  }

  async function updateMessage(messageId: string, content: string): Promise<void> {
    if (!activeSession.value) {
      return;
    }
    try {
      const updated = await updateMessageApi(activeSession.value, messageId, { content });
      const next = currentMessages.value.map((msg) =>
        msg.id === messageId ? updated : msg,
      );
      setMessages(activeSession.value, next);
    } catch (error) {
      message.error(parseApiError(error));
    }
  }

  async function toggleMessageVisibility(messageId: string): Promise<void> {
    if (!activeSession.value) {
      return;
    }
    const target = currentMessages.value.find((msg) => msg.id === messageId);
    if (!target) {
      return;
    }
    try {
      const updated = await updateMessageApi(activeSession.value, messageId, {
        visible: !target.visible,
      });
      const next = currentMessages.value.map((msg) =>
        msg.id === messageId ? updated : msg,
      );
      setMessages(activeSession.value, next);
    } catch (error) {
      message.error(parseApiError(error));
    }
  }

  async function deleteMessage(messageId: string): Promise<void> {
    if (!activeSession.value) {
      return;
    }
    try {
      await deleteMessageApi(activeSession.value, messageId);
      const next = currentMessages.value.filter((msg) => msg.id !== messageId);
      setMessages(activeSession.value, next);
    } catch (error) {
      message.error(parseApiError(error));
    }
  }

  function removeAttachment(messageId: string, attachmentName: string): void {
    if (!activeSession.value) {
      return;
    }
    const next = currentMessages.value.map((msg) => {
      if (msg.id !== messageId || !msg.attachments?.length) {
        return msg;
      }
      const remaining = msg.attachments.filter((att) => att.name !== attachmentName);
      return {
        ...msg,
        attachments: remaining.length ? remaining : undefined,
      };
    });
    setMessages(activeSession.value, next);
  }

  function addPendingAttachment(attachment: ChatAttachment): void {
    pendingAttachments.value = [...pendingAttachments.value, attachment];
  }

  function removePendingAttachment(index: number): void {
    pendingAttachments.value = pendingAttachments.value.filter((_, idx) => idx !== index);
  }

  function clearPendingAttachments(): void {
    pendingAttachments.value = [];
  }

  function enterBatchMode(action: Exclude<BatchAction, null>): void {
    batchAction.value = action;
    selectedIds.value = [];
  }

  function exitBatchMode(): void {
    batchAction.value = null;
    selectedIds.value = [];
  }

  function toggleSelection(messageId: string): void {
    if (selectedIds.value.includes(messageId)) {
      selectedIds.value = selectedIds.value.filter((id) => id !== messageId);
    } else {
      selectedIds.value = [...selectedIds.value, messageId];
    }
  }

  async function confirmBatchDelete(): Promise<void> {
    if (!activeSession.value) {
      return;
    }
    if (!selectedIds.value.length) {
      message.info("Select messages first.");
      return;
    }
    const ids = [...selectedIds.value];
    try {
      await Promise.all(ids.map((id) => deleteMessageApi(activeSession.value!, id)));
      const next = currentMessages.value.filter((msg) => !ids.includes(msg.id));
      setMessages(activeSession.value, next);
      exitBatchMode();
    } catch (error) {
      message.error(parseApiError(error));
    }
  }

  async function confirmBatchHide(): Promise<void> {
    if (!activeSession.value) {
      return;
    }
    if (!selectedIds.value.length) {
      message.info("Select messages first.");
      return;
    }
    const ids = [...selectedIds.value];
    try {
      const updates = await Promise.all(
        ids.map((id) =>
          updateMessageApi(activeSession.value!, id, { visible: false }),
        ),
      );
      const updatedMap = new Map(updates.map((msg) => [msg.id, msg]));
      const next = currentMessages.value.map((msg) => updatedMap.get(msg.id) ?? msg);
      setMessages(activeSession.value, next);
      exitBatchMode();
    } catch (error) {
      message.error(parseApiError(error));
    }
  }

  return {
    activeSession,
    currentMessages,
    pendingAttachments,
    batchAction,
    selectedIds,
    hasActiveSession,
    hasMessages,
    isBatchMode,
    isSending,
    isRstDataUpdating,
    hasRunningWork,
    setActiveSession,
    addMessage,
    sendMessage,
    cancelSending,
    cancelInFlightOperations,
    clearSessionRuntime,
    updateMessage,
    toggleMessageVisibility,
    deleteMessage,
    removeAttachment,
    addPendingAttachment,
    removePendingAttachment,
    clearPendingAttachments,
    enterBatchMode,
    exitBatchMode,
    toggleSelection,
    confirmBatchDelete,
    confirmBatchHide,
  };
});
