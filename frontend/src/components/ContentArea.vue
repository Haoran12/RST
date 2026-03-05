<template>
  <main class="content-area">
    <div v-if="isCurrentSessionClosed" class="content-empty">
      <div class="empty-title">{{ t("contentArea.closed.title") }}</div>
      <div class="empty-subtitle">{{ t("contentArea.closed.subtitle") }}</div>
    </div>
    <div v-else-if="!hasSession" class="content-empty">
      <div class="empty-title">Select a session to begin</div>
      <div class="empty-subtitle">Use the Sessions panel to create or load a chat.</div>
    </div>

    <div v-else ref="messagesContainer" class="content-scroll">
      <div v-if="!hasMessages" class="empty-hint">
        No messages yet. Write something below to start.
      </div>
      <div v-else class="message-list">
        <article
          v-for="(msg, index) in currentMessages"
          :id="`message-${index}`"
          :key="msg.id"
          class="message-card"
          :class="[
            `role-${msg.role}`,
            { 'is-hidden': !msg.visible },
          ]"
        >
          <header class="message-meta">
            <label v-if="isBatchMode" class="batch-select">
              <input
                type="checkbox"
                :checked="selectedIds.includes(msg.id)"
                @change="handleSelectionChange($event, msg.id)"
              />
            </label>
            <span class="meta-index">#{{ index + 1 }}</span>
            <span class="meta-role">{{ msg.role }}</span>
            <span class="meta-time">{{ formatTime(msg.timestamp) }}</span>

            <div v-if="!isBatchMode" class="meta-actions">
              <template v-if="editingId === msg.id">
                <button type="button" class="meta-button" @click="saveEdit(msg.id)">
                  Save
                </button>
                <button type="button" class="meta-button" @click="cancelEdit">
                  Cancel
                </button>
              </template>
              <template v-else>
                <button
                  type="button"
                  class="meta-button icon-only"
                  title="Copy message"
                  aria-label="Copy message"
                  @click="copyMessage(msg.content)"
                >
                  📑
                </button>
                <button
                  type="button"
                  class="meta-button icon-only"
                  :class="{ 'is-toggled': !msg.visible }"
                  :title="msg.visible ? 'Hide message' : 'Show message'"
                  :aria-label="msg.visible ? 'Hide message' : 'Show message'"
                  @click="chatStore.toggleMessageVisibility(msg.id)"
                >
                  {{ msg.visible ? "👁" : "🙈" }}
                </button>
                <button type="button" class="meta-button" @click="startEdit(msg)">
                  ✏
                </button>
                <button
                  type="button"
                  class="meta-button danger"
                  @click="handleDelete(msg.id)"
                >
                  🗑
                </button>
              </template>
            </div>
          </header>

          <div class="message-body">
            <div v-if="editingId === msg.id" class="edit-area">
              <textarea
                v-model="editContent"
                class="edit-textarea"
                @keydown.esc.prevent="cancelEdit"
              ></textarea>
            </div>
            <MarkdownMessage
              v-else
              :content="formatMessageContent(msg.content)"
              class="message-text"
            />

            <div v-if="msg.attachments?.length" class="attachment-list">
              <div v-for="file in msg.attachments" :key="file.name" class="attachment-chip">
                <span class="attachment-name">{{ file.name }}</span>
                <span class="attachment-size">({{ formatSize(file.size) }})</span>
                <button
                  type="button"
                  class="attachment-remove"
                  title="Remove attachment"
                  @click="removeAttachment(msg.id, file.name)"
                >
                  Remove
                </button>
              </div>
            </div>
          </div>
        </article>
      </div>
    </div>

    <div v-if="isBatchMode" class="batch-bar">
      <div class="batch-info">
        {{ selectedIds.length }} {{ t("contentArea.batch.selected") }}
      </div>
      <button
        type="button"
        class="batch-button"
        :class="{ danger: batchAction === 'delete' }"
        @click="handleBatchConfirm"
      >
        {{ batchAction === "delete" ? t("contentArea.batch.confirm_delete") : t("contentArea.batch.confirm_hide") }}
      </button>
      <button type="button" class="batch-button secondary" @click="chatStore.exitBatchMode">
        {{ t("common.cancel") }}
      </button>
    </div>
  </main>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import { dialog, message } from "@/utils/message";

import { useI18n } from "@/composables/useI18n";
import MarkdownMessage from "@/components/MarkdownMessage.vue";
import type { ChatMessage } from "@/types/chat";
import { useChatStore } from "@/stores/chat";
import { useSessionStore } from "@/stores/session";
import { formatTimestampLocal } from "@/utils/time";

const chatStore = useChatStore();
const sessionStore = useSessionStore();
const { t } = useI18n();
const { activeSession, batchAction, currentMessages, isBatchMode, selectedIds } = storeToRefs(chatStore);
const { currentSession } = storeToRefs(sessionStore);

const messagesContainer = ref<HTMLDivElement | null>(null);
const editingId = ref<string | null>(null);
const editContent = ref("");
const GOTO_MESSAGE_EVENT = "rst-chat-goto-message";

const hasSession = computed(() => Boolean(activeSession.value));
const isCurrentSessionClosed = computed(() => Boolean(currentSession.value?.is_closed));
const hasMessages = computed(() => currentMessages.value.length > 0);

const scrollToBottom = async () => {
  await nextTick();
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight;
  }
};

const scrollToMessageTop = async (index: number) => {
  await nextTick();
  const container = messagesContainer.value;
  if (!container) {
    return;
  }
  const target = container.querySelector<HTMLElement>(`#message-${index}`);
  if (!target) {
    return;
  }
  const offset = target.offsetTop - container.offsetTop;
  container.scrollTop = Math.max(0, offset);
};

watch(
  () => currentMessages.value.length,
  () => {
    scrollToBottom();
  },
);

watch(
  () => activeSession.value,
  () => {
    editingId.value = null;
    editContent.value = "";
    scrollToBottom();
  },
  { immediate: true },
);

const handleGotoMessage = (event: Event) => {
  const customEvent = event as CustomEvent<{ index?: number }>;
  const index = customEvent.detail?.index;
  if (typeof index !== "number" || Number.isNaN(index)) {
    return;
  }
  void scrollToMessageTop(index);
};

const handleEscapeKey = (event: KeyboardEvent) => {
  if (event.key !== "Escape") {
    return;
  }
  if (!editingId.value) {
    return;
  }
  event.preventDefault();
  cancelEdit();
};

onMounted(() => {
  if (typeof window === "undefined") {
    return;
  }
  window.addEventListener(GOTO_MESSAGE_EVENT, handleGotoMessage as EventListener);
  window.addEventListener("keydown", handleEscapeKey as EventListener);
});

onUnmounted(() => {
  if (typeof window === "undefined") {
    return;
  }
  window.removeEventListener(GOTO_MESSAGE_EVENT, handleGotoMessage as EventListener);
  window.removeEventListener("keydown", handleEscapeKey as EventListener);
});

const startEdit = (msg: ChatMessage) => {
  editingId.value = msg.id;
  editContent.value = msg.content;
};

const saveEdit = async (id: string) => {
  const next = editContent.value.trim();
  if (!next) {
    message.warning("Message content cannot be empty.");
    return;
  }
  await chatStore.updateMessage(id, next);
  editingId.value = null;
  editContent.value = "";
};

const cancelEdit = () => {
  editingId.value = null;
  editContent.value = "";
};

const copyMessage = async (content: string) => {
  const text = content ?? "";
  try {
    if (typeof navigator !== "undefined" && navigator.clipboard?.writeText) {
      await navigator.clipboard.writeText(text);
      message.success("Message copied.");
      return;
    }
  } catch {
    // Fallback handled below.
  }

  if (typeof document === "undefined") {
    message.error("Failed to copy message.");
    return;
  }

  const textarea = document.createElement("textarea");
  textarea.value = text;
  textarea.setAttribute("readonly", "");
  textarea.style.position = "fixed";
  textarea.style.opacity = "0";
  document.body.appendChild(textarea);
  textarea.select();

  let copied = false;
  try {
    copied = document.execCommand("copy");
  } catch {
    copied = false;
  } finally {
    document.body.removeChild(textarea);
  }

  if (copied) {
    message.success("Message copied.");
    return;
  }
  message.error("Failed to copy message.");
};

const handleSelectionChange = (event: Event, messageId: string) => {
  const target = event.target as HTMLInputElement | null;
  chatStore.toggleSelection(messageId, target?.checked ?? false);
};

function confirmDangerAction(content: string): Promise<boolean> {
  return new Promise((resolve) => {
    let settled = false;
    const settle = (value: boolean) => {
      if (settled) {
        return;
      }
      settled = true;
      resolve(value);
    };

    dialog.warning({
      title: t("common.confirm"),
      content,
      positiveText: t("contentArea.batch.confirm_delete"),
      negativeText: t("common.cancel"),
      positiveButtonProps: { type: "error" },
      maskClosable: false,
      onPositiveClick: () => settle(true),
      onNegativeClick: () => settle(false),
      onClose: () => settle(false),
    });
  });
}

const handleDelete = async (id: string) => {
  const confirmed = await confirmDangerAction("Delete this message?");
  if (confirmed) {
    await chatStore.deleteMessage(id);
  }
};

const handleBatchConfirm = async () => {
  if (batchAction.value === "delete") {
    const confirmed = await confirmDangerAction(t("contentArea.batch.delete_prompt"));
    if (confirmed) {
      await chatStore.confirmBatchDelete();
    }
    return;
  }
  await chatStore.confirmBatchHide();
};

const formatTime = (timestamp: string) => {
  return formatTimestampLocal(timestamp, timestamp);
};

const formatSize = (bytes: number) => {
  if (!bytes) {
    return "0 B";
  }
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(k)), sizes.length - 1);
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
};

const removeAttachment = async (messageId: string, attachmentName: string) => {
  const confirmed = await confirmDangerAction(`Remove attachment "${attachmentName}"?`);
  if (!confirmed) {
    return;
  }
  await chatStore.removeAttachment(messageId, attachmentName);
};

const formatMessageContent = (content: string) => {
  if (!content) {
    return "";
  }
  // Hide <...> tags by default by removing them from display content,
  // but keep <scene> tags as they have special rendering in MarkdownMessage.
  return content.replace(/<(?!scene|\/scene)[^>]+>/g, "").trim();
};
</script>

<style scoped lang="scss">
.content-area {
  position: relative;
  display: flex;
  flex-direction: column;
  flex: 1;
  min-height: 0;
  background: var(--rst-bg-secondary);
}

.content-empty {
  flex: 1;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  text-align: center;
  padding: 24px;
  color: var(--rst-text-secondary);
}

.empty-title {
  font-size: 18px;
  font-weight: 600;
  color: var(--rst-text-primary);
}

.empty-subtitle {
  margin-top: 6px;
  font-size: 13px;
}

.content-scroll {
  flex: 1;
  overflow-y: auto;
  padding: 24px;
}

.empty-hint {
  text-align: center;
  color: var(--rst-text-secondary);
  font-size: 13px;
  padding: 16px 0;
}

.message-list {
  max-width: 880px;
  margin: 0 auto;
  display: flex;
  flex-direction: column;
  gap: 16px;
  padding-bottom: 120px;
}

.message-card {
  border-radius: 12px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-panel);
  padding: 12px 16px;
  transition: background 0.2s ease, border-color 0.2s ease, opacity 0.2s ease;
}

.message-card.role-user {
  border-color: rgba(34, 197, 94, 0.3);
  background: rgba(34, 197, 94, 0.08);
}

.message-card.role-assistant {
  border-color: rgba(59, 130, 246, 0.3);
  background: rgba(59, 130, 246, 0.08);
}

.message-card.role-system {
  border-color: rgba(245, 158, 11, 0.35);
  background: rgba(245, 158, 11, 0.08);
}

.message-card.is-hidden {
  opacity: 0.55;
}

.message-meta {
  display: flex;
  flex-wrap: wrap;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.batch-select input {
  width: 14px;
  height: 14px;
}

.meta-index {
  font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace;
}

.meta-role {
  text-transform: uppercase;
  letter-spacing: 0.08em;
  font-weight: 600;
}

.meta-actions {
  margin-left: auto;
  display: flex;
  gap: 8px;
}

.meta-button {
  border: 1px solid var(--rst-border-color);
  background: transparent;
  color: var(--rst-text-secondary);
  font-size: 12px;
  padding: 2px 8px;
  border-radius: 6px;
  cursor: pointer;
  transition: all 0.2s ease;
}

.meta-button:hover {
  border-color: var(--rst-accent);
  color: var(--rst-text-primary);
}

.meta-button.danger:hover {
  border-color: var(--rst-danger);
  color: var(--rst-danger);
}

.meta-button.icon-only {
  width: 28px;
  height: 22px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 0;
  line-height: 1;
}

.meta-button.icon-only.is-toggled {
  border-color: var(--rst-accent);
  color: var(--rst-accent);
}

.message-body {
  margin-top: 10px;
}

.message-text {
  color: var(--rst-text-primary);
}

.edit-area {
  display: flex;
}

.edit-textarea {
  width: 100%;
  min-height: 320px;
  border-radius: 8px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-secondary);
  color: var(--rst-text-primary);
  font-family: var(--rst-font-family);
  font-size: calc(14px * var(--rst-font-size-scale));
  line-height: 1.7;
  padding: 10px 12px;
  resize: vertical;
}

.attachment-list {
  margin-top: 12px;
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
}

.attachment-chip {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  padding: 4px 10px;
  border-radius: 999px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-secondary);
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.attachment-name {
  color: var(--rst-text-primary);
  max-width: 160px;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.attachment-remove {
  border: none;
  background: transparent;
  color: var(--rst-danger);
  font-size: 11px;
  cursor: pointer;
}

.batch-bar {
  position: absolute;
  left: 50%;
  bottom: 16px;
  transform: translateX(-50%);
  display: flex;
  align-items: center;
  gap: 12px;
  padding: 10px 16px;
  border-radius: 999px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-panel);
  box-shadow: 0 12px 24px rgba(0, 0, 0, 0.3);
  z-index: 2;
}

.batch-info {
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.batch-button {
  border-radius: 999px;
  border: 1px solid var(--rst-accent);
  background: var(--rst-accent);
  color: #fff;
  font-size: 12px;
  padding: 4px 12px;
  cursor: pointer;
}

.batch-button.danger {
  border-color: var(--rst-danger);
  background: var(--rst-danger);
}

.batch-button.secondary {
  border-color: var(--rst-border-color);
  background: transparent;
  color: var(--rst-text-secondary);
}

@media (max-width: 720px) {
  .content-scroll {
    padding: 16px;
  }

  .message-card {
    padding: 12px;
  }
}
</style>
