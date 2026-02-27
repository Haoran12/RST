<template>
  <main class="content-area">
    <div v-if="!hasSession" class="content-empty">
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
          :key="msg.id"
          :id="`message-${index}`"
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
                @change="chatStore.toggleSelection(msg.id)"
              />
            </label>
            <span class="meta-index">#{{ index }}</span>
            <span class="meta-role">{{ msg.role }}</span>
            <span class="meta-time">{{ formatTime(msg.timestamp) }}</span>

            <div v-if="editingId !== msg.id && !isBatchMode" class="meta-actions">
              <button
                type="button"
                class="meta-button"
                @click="chatStore.toggleMessageVisibility(msg.id)"
              >
                {{ msg.visible ? "Hide" : "Show" }}
              </button>
              <button type="button" class="meta-button" @click="startEdit(msg)">
                Edit
              </button>
              <button
                type="button"
                class="meta-button danger"
                @click="handleDelete(msg.id)"
              >
                Delete
              </button>
            </div>
          </header>

          <div class="message-body">
            <div v-if="editingId === msg.id" class="edit-area">
              <textarea v-model="editContent" class="edit-textarea"></textarea>
              <div class="edit-actions">
                <button type="button" class="meta-button" @click="saveEdit(msg.id)">
                  Save
                </button>
                <button type="button" class="meta-button" @click="cancelEdit">
                  Cancel
                </button>
              </div>
            </div>
            <div v-else class="message-text">{{ msg.content }}</div>

            <div v-if="msg.attachments?.length" class="attachment-list">
              <div v-for="file in msg.attachments" :key="file.name" class="attachment-chip">
                <span class="attachment-name">{{ file.name }}</span>
                <span class="attachment-size">({{ formatSize(file.size) }})</span>
                <button
                  type="button"
                  class="attachment-remove"
                  @click="removeAttachment(msg.id, file.name)"
                  title="Remove attachment"
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
        {{ selectedIds.length }} selected
      </div>
      <button
        type="button"
        class="batch-button"
        @click="handleBatchConfirm"
      >
        {{ batchAction === "delete" ? "Confirm Delete" : "Confirm Hide" }}
      </button>
      <button type="button" class="batch-button secondary" @click="chatStore.exitBatchMode">
        Cancel
      </button>
    </div>
  </main>
</template>

<script setup lang="ts">
import { computed, nextTick, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import { message } from "@/utils/message";

import type { ChatMessage } from "@/types/chat";
import { useChatStore } from "@/stores/chat";

const chatStore = useChatStore();
const { activeSession, batchAction, currentMessages, isBatchMode, selectedIds } = storeToRefs(chatStore);

const messagesContainer = ref<HTMLDivElement | null>(null);
const editingId = ref<string | null>(null);
const editContent = ref("");

const hasSession = computed(() => Boolean(activeSession.value));
const hasMessages = computed(() => currentMessages.value.length > 0);

const scrollToBottom = async () => {
  await nextTick();
  if (messagesContainer.value) {
    messagesContainer.value.scrollTop = messagesContainer.value.scrollHeight;
  }
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

const startEdit = (msg: ChatMessage) => {
  editingId.value = msg.id;
  editContent.value = msg.content;
};

const saveEdit = (id: string) => {
  const next = editContent.value.trim();
  if (!next) {
    message.warning("Message content cannot be empty.");
    return;
  }
  chatStore.updateMessage(id, next);
  editingId.value = null;
  editContent.value = "";
};

const cancelEdit = () => {
  editingId.value = null;
  editContent.value = "";
};

const handleDelete = (id: string) => {
  if (confirm("Delete this message?")) {
    chatStore.deleteMessage(id);
  }
};

const handleBatchConfirm = () => {
  if (batchAction.value === "delete") {
    if (confirm(`Delete ${selectedIds.value.length} messages?`)) {
      chatStore.confirmBatchDelete();
    }
    return;
  }
  chatStore.confirmBatchHide();
};

const formatTime = (timestamp: string) => {
  const parsed = new Date(timestamp);
  if (Number.isNaN(parsed.getTime())) {
    return timestamp;
  }
  return parsed.toLocaleString();
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

const removeAttachment = (messageId: string, attachmentName: string) => {
  if (!confirm(`Remove attachment "${attachmentName}"?`)) {
    return;
  }
  chatStore.removeAttachment(messageId, attachmentName);
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

.message-body {
  margin-top: 10px;
}

.message-text {
  white-space: pre-wrap;
  font-size: 14px;
  line-height: 1.6;
  color: var(--rst-text-primary);
}

.edit-area {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.edit-textarea {
  width: 100%;
  min-height: 160px;
  border-radius: 8px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-secondary);
  color: var(--rst-text-primary);
  padding: 10px 12px;
  resize: vertical;
}

.edit-actions {
  display: flex;
  gap: 8px;
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
