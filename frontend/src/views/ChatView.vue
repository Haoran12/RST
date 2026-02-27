<template>
  <section class="chat-shell">
    <header class="chat-shell__topbar">
      <div class="chat-shell__controls">
        <div class="quick-select">
          <span class="quick-label">Session</span>
          <n-select
            size="small"
            :value="selectedSession"
            :options="sessionOptions"
            :loading="sessionLoading"
            placeholder="Select session"
            @update:value="handleSessionSelect"
          />
          <span
            v-if="currentSession"
            class="session-state-pill"
            :class="{ 'is-closed': currentSession.is_closed }"
          >
            {{ currentSession.is_closed ? "Closed" : "Open" }}
          </span>
        </div>
        <div class="quick-select">
          <span class="quick-label">Appearance</span>
          <n-select
            v-model:value="theme"
            size="small"
            :options="themeOptions"
          />
        </div>
      </div>
      <div class="chat-shell__status">
        <span class="status-label">Backend</span>
        <span :class="['status-pill', `is-${status}`]">{{ statusText }}</span>
        <span class="model-pill" :title="currentModelDisplay">{{ currentModelDisplay }}</span>
      </div>
    </header>

    <div class="chat-shell__body" @click="handleChatBodyClick">
      <PanelShell />
      <div class="chat-shell__workspace">
        <div class="chat-shell__content">
          <ContentArea />
        </div>

        <div class="chat-shell__input">
          <div class="input-inner">
            <div v-if="pendingAttachments.length" class="input-attachments">
              <div
                v-for="(file, index) in pendingAttachments"
                :key="`${file.name}-${index}`"
                class="attachment-item"
              >
                <span class="attachment-name" :title="file.name">{{ file.name }}</span>
                <span class="attachment-size">({{ formatSize(file.size) }})</span>
                <button
                  type="button"
                  class="attachment-remove"
                  @click="chatStore.removePendingAttachment(index)"
                >
                  Remove
                </button>
              </div>
            </div>

            <div class="input-row">
              <InputMenu />
              <textarea
                ref="inputRef"
                v-model="inputText"
                class="chat-input"
                :placeholder="inputPlaceholder"
                :disabled="!currentSession || currentSessionClosed"
                @keydown="handleKeyDown"
              ></textarea>
              <button
                type="button"
                class="send-button"
                :class="{ 'is-stop': isSending }"
                :disabled="!canSend"
                @click="handleSend"
              >
                {{ isSending ? "Stop" : "Send" }}
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, nextTick, onMounted, onUnmounted, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import { NSelect } from "naive-ui";

import { fetchHealth } from "@/api/health";
import ContentArea from "@/components/ContentArea.vue";
import InputMenu from "@/components/InputMenu.vue";
import PanelShell from "@/components/panels/PanelShell.vue";
import { useApiConfigStore } from "@/stores/api-config";
import { useAppearanceStore } from "@/stores/appearance";
import { useChatStore } from "@/stores/chat";
import { useSessionStore } from "@/stores/session";
import { message } from "@/utils/message";
import { confirmLeaveSessionWhileBusy } from "@/utils/session-leave-guard";

type HealthState = "checking" | "ok" | "error";

const sessionStore = useSessionStore();
const apiConfigStore = useApiConfigStore();
const chatStore = useChatStore();
const appearanceStore = useAppearanceStore();
const { sessions, currentSession, loading: sessionLoading } = storeToRefs(sessionStore);
const { configs: apiConfigs } = storeToRefs(apiConfigStore);
const { theme } = storeToRefs(appearanceStore);
const { pendingAttachments, isSending } = storeToRefs(chatStore);

const sessionOptions = computed(() =>
  sessions.value.map((session) => ({ label: session.name, value: session.name })),
);
const selectedSession = computed(() => currentSession.value?.name ?? null);
const themeOptions = appearanceStore.themeOptions;
const currentSessionClosed = computed(() => Boolean(currentSession.value?.is_closed));
const currentModelDisplay = computed(() => {
  const configId = currentSession.value?.main_api_config_id;
  if (!configId) {
    return "- : -";
  }
  const matched = apiConfigs.value.find((item) => item.id === configId);
  if (!matched) {
    return "- : -";
  }
  const apiName = matched.name.trim();
  const model = matched.model.trim();
  const left = apiName.length > 0 ? apiName : "-";
  const right = model.length > 0 ? model : "-";
  return `${left} : ${right}`;
});

const status = ref<HealthState>("checking");
const inputText = ref("");
const inputRef = ref<HTMLTextAreaElement | null>(null);
let healthProbeTimer: number | null = null;
const HEALTH_PROBE_INTERVAL_MS = 15000;

const statusText = computed(() => status.value);
const inputPlaceholder = computed(() => {
  if (!currentSession.value) {
    return "Select a session before sending.";
  }
  if (currentSession.value.is_closed) {
    return "Current session is closed. Re-open it in Session panel.";
  }
  return "Type your message... (Ctrl+Enter to send)";
});
const canSend = computed(() => {
  if (!currentSession.value) {
    return false;
  }
  if (currentSession.value.is_closed) {
    return false;
  }
  return true;
});

onMounted(async () => {
  sessionStore.loadSessions();
  apiConfigStore.loadConfigs();
  await probeHealth();
  if (typeof window !== "undefined") {
    healthProbeTimer = window.setInterval(() => {
      void probeHealth();
    }, HEALTH_PROBE_INTERVAL_MS);
  }
});

onUnmounted(() => {
  if (typeof window === "undefined" || healthProbeTimer === null) {
    return;
  }
  window.clearInterval(healthProbeTimer);
  healthProbeTimer = null;
});

watch(
  () => ({
    name: currentSession.value?.name ?? null,
    isClosed: Boolean(currentSession.value?.is_closed),
  }),
  ({ name, isClosed }) => {
    if (isClosed && name) {
      chatStore.cancelInFlightOperations();
      chatStore.clearSessionRuntime(name);
      chatStore.setActiveSession(null);
    } else {
      chatStore.setActiveSession(name);
    }
    inputText.value = "";
    chatStore.clearPendingAttachments();
    nextTick(adjustTextareaHeight);
  },
  { immediate: true },
);

watch(inputText, () => {
  adjustTextareaHeight();
});

async function handleSessionSelect(value: string) {
  if (value === selectedSession.value) {
    return;
  }
  if (!(await confirmLeaveIfBusy())) {
    return;
  }
  sessionStore.loadSession(value);
}

async function confirmLeaveIfBusy(): Promise<boolean> {
  if (!chatStore.hasRunningWork) {
    return true;
  }
  const confirmed = await confirmLeaveSessionWhileBusy();
  if (!confirmed) {
    return false;
  }
  chatStore.cancelInFlightOperations();
  return true;
}

async function probeHealth() {
  try {
    // Keep top-right backend status in sync with real connectivity.
    const data = await fetchHealth();
    status.value = data.status === "ok" ? "ok" : "error";
  } catch (_error) {
    status.value = "error";
  }
}

function handleChatBodyClick() {
  if (typeof window === "undefined") {
    return;
  }
  window.dispatchEvent(new CustomEvent("rst-chat-area-click"));
}

function adjustTextareaHeight() {
  if (!inputRef.value) {
    return;
  }
  inputRef.value.style.height = "auto";
  const maxHeight = window.innerHeight * 0.4;
  const nextHeight = Math.min(inputRef.value.scrollHeight, maxHeight);
  inputRef.value.style.height = `${nextHeight}px`;
}

function handleSend() {
  if (isSending.value) {
    chatStore.cancelSending();
    return;
  }
  if (!currentSession.value) {
    message.error("Select a session before sending.");
    return;
  }
  if (currentSession.value.is_closed) {
    message.error("Current session is closed.");
    return;
  }
  const content = inputText.value.trim();
  const attachments = pendingAttachments.value.map((item) => ({ ...item }));
  void chatStore.sendMessage(content, attachments);

  inputText.value = "";
  chatStore.clearPendingAttachments();
  nextTick(adjustTextareaHeight);
}

function handleKeyDown(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
    event.preventDefault();
    handleSend();
  }
}

function formatSize(bytes: number) {
  if (!bytes) {
    return "0 B";
  }
  const k = 1024;
  const sizes = ["B", "KB", "MB", "GB"];
  const i = Math.min(Math.floor(Math.log(bytes) / Math.log(k)), sizes.length - 1);
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
}
</script>

<style scoped lang="scss">
.chat-shell {
  display: flex;
  flex-direction: column;
  height: 100%;
  background: var(--rst-bg-secondary);
}

.chat-shell__topbar {
  min-height: 44px;
  background: var(--rst-bg-topbar);
  border-bottom: 1px solid var(--rst-border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 6px 20px;
}

.chat-shell__controls {
  display: flex;
  align-items: center;
  gap: 16px;
  flex: 1;
  min-width: 0;
  flex-wrap: wrap;
}

.quick-select {
  display: flex;
  align-items: center;
  gap: 6px;
}

.session-state-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 2px 10px;
  border-radius: 999px;
  border: 1px solid var(--rst-border-color);
  color: var(--rst-success);
  font-size: 11px;
  line-height: 1.2;
  text-transform: uppercase;
}

.session-state-pill.is-closed {
  color: var(--rst-danger);
}

.quick-label {
  font-size: 11px;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: var(--rst-text-secondary);
  white-space: nowrap;
}

.quick-select :deep(.n-select) {
  min-width: 160px;
}

.chat-shell__status {
  display: flex;
  align-items: center;
  gap: 8px;
  font-size: 12px;
  color: var(--rst-text-secondary);
}

.status-label {
  text-transform: uppercase;
  letter-spacing: 0.12em;
  font-size: 11px;
}

.status-pill {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  padding: 2px 10px;
  border-radius: 999px;
  font-weight: 600;
  color: #111111;
  background: #9ca3af;
  text-transform: uppercase;
  font-size: 10px;
}

.status-pill.is-checking {
  background: #9ca3af;
}

.status-pill.is-ok {
  background: #22c55e;
}

.status-pill.is-error {
  background: #ef4444;
}

.model-pill {
  display: inline-flex;
  align-items: center;
  max-width: 320px;
  padding: 2px 10px;
  border-radius: 999px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-secondary);
  color: var(--rst-text-primary);
  font-size: 11px;
  line-height: 1.2;
  white-space: nowrap;
  overflow: hidden;
  text-overflow: ellipsis;
}

.chat-shell__body {
  flex: 1;
  display: flex;
  min-height: 0;
  overflow: hidden;
}

.chat-shell__workspace {
  flex: 1;
  min-width: 0;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

.chat-shell__content {
  flex: 1;
  min-height: 0;
  display: flex;
}

.chat-shell__input {
  border-top: 1px solid var(--rst-border-color);
  background: var(--rst-bg-panel);
  padding: 12px 20px;
}

.input-inner {
  max-width: 880px;
  margin: 0 auto;
  width: 100%;
  display: flex;
  flex-direction: column;
  gap: 10px;
}

.input-attachments {
  display: flex;
  flex-wrap: wrap;
  gap: 8px;
  padding-bottom: 10px;
  border-bottom: 1px solid var(--rst-border-color);
  margin: 0;
}

.attachment-item {
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

.input-row {
  display: flex;
  align-items: flex-end;
  gap: 12px;
}

.chat-input {
  flex: 1;
  min-height: 44px;
  max-height: 50vh;
  padding: 10px 12px;
  border-radius: 10px;
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-secondary);
  color: var(--rst-text-primary);
  font-size: 14px;
  line-height: 1.5;
  resize: none;
}

.chat-input:focus {
  outline: none;
  border-color: var(--rst-accent);
  box-shadow: 0 0 0 2px rgba(37, 99, 235, 0.2);
}

.send-button {
  border-radius: 10px;
  border: 1px solid var(--rst-accent);
  background: var(--rst-accent);
  color: #fff;
  padding: 10px 18px;
  font-size: 13px;
  cursor: pointer;
  transition: opacity 0.2s ease, transform 0.2s ease;
}

.send-button.is-stop {
  border-color: #dc2626;
  background: #dc2626;
}

.send-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
  transform: none;
}

@media (max-width: 640px) {
  .chat-shell__topbar {
    padding: 6px 12px;
    gap: 12px;
  }

  .quick-select :deep(.n-select) {
    min-width: 140px;
  }

  .chat-shell__input {
    padding: 10px 12px;
  }

  .input-row {
    flex-direction: column;
    align-items: stretch;
  }

  .send-button {
    width: 100%;
  }
}
</style>
