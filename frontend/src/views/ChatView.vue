<template>
  <section class="chat-shell">
    <header class="chat-shell__topbar">
      <div class="chat-shell__controls">
        <div class="quick-select">
          <span class="quick-label">{{ t("topbar.session.label") }}</span>
          <n-select
            size="small"
            :value="selectedSession"
            :options="sessionOptions"
            :loading="sessionLoading"
            :placeholder="t('topbar.session.select_placeholder')"
            @update:value="handleSessionSelect"
          />
          <button
            type="button"
            class="session-close-button"
            :disabled="!currentSession || currentSession.is_closed || sessionLoading"
            @click="handleCloseSession"
          >
            {{ t("topbar.session.action.close") }}
          </button>
        </div>
        <div class="quick-select">
          <span class="quick-label">{{ t("topbar.appearance.label") }}</span>
          <n-select v-model:value="theme" size="small" :options="themeOptions" />
        </div>
        <div class="quick-select">
          <span class="quick-label">{{ t("topbar.language.label") }}</span>
          <n-select
            size="small"
            :value="locale"
            :options="languageOptions"
            @update:value="handleLocaleSelect"
          />
        </div>
      </div>
      <div class="chat-shell__status">
        <span class="status-label">{{ t("topbar.status.backend") }}</span>
        <span :class="['status-pill', `is-${status}`]">{{ statusText }}</span>
        <span class="model-pill" :title="currentModelDisplay">{{ currentModelDisplay }}</span>
      </div>
    </header>

    <div class="chat-shell__body" @click="handleChatBodyClick">
      <PanelShell />
      <div class="chat-shell__workspace">
        <div class="chat-shell__content">
          <ContentArea />
          <StatusPanel class="chat-shell__status-panel" />
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
                  {{ t("input.attachments.remove") }}
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
                {{ isSending ? t("input.send.stop") : t("input.send.send") }}
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
import { useI18n } from "@/composables/useI18n";
import ContentArea from "@/components/ContentArea.vue";
import InputMenu from "@/components/InputMenu.vue";
import StatusPanel from "@/components/StatusPanel.vue";
import PanelShell from "@/components/panels/PanelShell.vue";
import { useApiConfigStore } from "@/stores/api-config";
import { useAppearanceStore, type ThemeMode } from "@/stores/appearance";
import { useChatStore } from "@/stores/chat";
import { useLanguageStore } from "@/stores/language";
import { useLoreStore } from "@/stores/lore";
import { useSessionStore } from "@/stores/session";
import { message } from "@/utils/message";
import { confirmLeaveSessionWhileBusy } from "@/utils/session-leave-guard";

type HealthState = "checking" | "ok" | "error";
type FloorToken = number | "all";
type FloorTarget = {
  kind: "single" | "range";
  indexes: number[];
};

const sessionStore = useSessionStore();
const apiConfigStore = useApiConfigStore();
const chatStore = useChatStore();
const appearanceStore = useAppearanceStore();
const languageStore = useLanguageStore();
const loreStore = useLoreStore();
const { t } = useI18n();
const { sessions, currentSession, loading: sessionLoading } = storeToRefs(sessionStore);
const { configs: apiConfigs } = storeToRefs(apiConfigStore);
const { theme } = storeToRefs(appearanceStore);
const { locale } = storeToRefs(languageStore);
const { loading: loreLoading, scheduleStatus, syncStatus } = storeToRefs(loreStore);
const { currentMessages, pendingAttachments, isSending } = storeToRefs(chatStore);

const sessionOptions = computed(() =>
  sessions.value.map((session) => ({ label: session.name, value: session.name })),
);
const selectedSession = computed(() => {
  if (!currentSession.value) {
    return null;
  }
  return currentSession.value.is_closed ? null : currentSession.value.name;
});
const themeOptions = computed<Array<{ label: string; value: ThemeMode }>>(() => [
  { label: t("topbar.appearance.theme.dark"), value: "dark" },
  { label: t("topbar.appearance.theme.light"), value: "light" },
]);
const languageOptions = languageStore.languageOptions;
const currentSessionClosed = computed(() => Boolean(currentSession.value?.is_closed));
const currentModelDisplay = computed(() => {
  const configId = currentSession.value?.main_api_config_id;
  if (!configId) {
    return t("topbar.model.fallback");
  }
  const matched = apiConfigs.value.find((item) => item.id === configId);
  if (!matched) {
    return t("topbar.model.fallback");
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
const GOTO_MESSAGE_EVENT = "rst-chat-goto-message";
let healthProbeTimer: number | null = null;
const HEALTH_PROBE_INTERVAL_MS = 15000;
const statusTextKeyByState: Record<HealthState, string> = {
  checking: "topbar.status.checking",
  ok: "topbar.status.ok",
  error: "topbar.status.error",
};

const statusText = computed(() => t(statusTextKeyByState[status.value]));
const inputPlaceholder = computed(() => {
  if (!currentSession.value) {
    return t("input.placeholder.select_session");
  }
  if (currentSession.value.is_closed) {
    return t("input.placeholder.session_closed");
  }
  return t("input.placeholder.default");
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
const hasRunningRstService = computed(
  () =>
    currentSession.value?.mode === "RST" &&
    (Boolean(scheduleStatus.value?.running) || Boolean(syncStatus.value?.running)),
);
const hasRunningRequests = computed(
  () => chatStore.hasRunningWork || loreLoading.value || hasRunningRstService.value,
);

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
  const isSameSelection = value === selectedSession.value;
  if (isSameSelection && currentSession.value && !currentSession.value.is_closed) {
    return;
  }
  if (!isSameSelection && !(await confirmLeaveIfBusy())) {
    return;
  }
  await sessionStore.loadSession(value);
  if (sessionStore.currentSession?.name !== value) {
    return;
  }
  if (sessionStore.currentSession.is_closed) {
    await sessionStore.saveSession(value, { is_closed: false });
  }
}

async function handleCloseSession() {
  if (!currentSession.value || currentSession.value.is_closed) {
    return;
  }
  if (!(await confirmLeaveIfBusy())) {
    return;
  }
  await sessionStore.saveSession(currentSession.value.name, { is_closed: true });
}

function handleLocaleSelect(value: string | null) {
  if (value === null || value === locale.value) {
    return;
  }
  if (value === "en" || value === "zh-CN") {
    languageStore.setLocale(value);
  }
}

async function confirmLeaveIfBusy(): Promise<boolean> {
  if (!hasRunningRequests.value) {
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
  } catch {
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

function formatText(key: string, params: Record<string, string | number>): string {
  let text = t(key);
  Object.entries(params).forEach(([paramKey, paramValue]) => {
    text = text.replaceAll(`{${paramKey}}`, String(paramValue));
  });
  return text;
}

function parseFloorToken(rawToken: string, total: number): FloorToken | null {
  const token = rawToken.trim().toLowerCase();
  if (token === "all") {
    return "all";
  }
  if (token === "cur") {
    return total > 0 ? total - 1 : null;
  }
  const match = token.match(/^(\d+)$/);
  if (!match) {
    return null;
  }
  const floor = Number(match[1]);
  if (!Number.isInteger(floor) || floor < 1 || floor > total) {
    return null;
  }
  return floor - 1;
}

function parseFloorTarget(rawArg: string, total: number): FloorTarget | null {
  const compact = rawArg.trim().toLowerCase().replace(/\s*-\s*/g, "-");
  if (!compact || /\s/.test(compact)) {
    return null;
  }
  const allIndexes = Array.from({ length: total }, (_, index) => index);
  if (!compact.includes("-")) {
    const index = parseFloorToken(compact, total);
    if (index === null) {
      return null;
    }
    if (index === "all") {
      return {
        kind: "range",
        indexes: allIndexes,
      };
    }
    return {
      kind: "single",
      indexes: [index],
    };
  }
  const segments = compact.split("-");
  if (segments.length !== 2) {
    return null;
  }
  const start = parseFloorToken(segments[0], total);
  const end = parseFloorToken(segments[1], total);
  if (start === null || end === null) {
    return null;
  }
  if (start === "all" && end === "all") {
    return {
      kind: "range",
      indexes: allIndexes,
    };
  }
  if (start === "all") {
    const endIndex = end as number;
    const indexes: number[] = [];
    for (let index = 0; index <= endIndex; index += 1) {
      indexes.push(index);
    }
    return {
      kind: "range",
      indexes,
    };
  }
  if (end === "all") {
    const startIndex = start as number;
    const indexes: number[] = [];
    for (let index = startIndex; index <= total - 1; index += 1) {
      indexes.push(index);
    }
    return {
      kind: "range",
      indexes,
    };
  }
  const startIndex = start as number;
  const endIndex = end as number;
  const from = Math.min(startIndex, endIndex);
  const to = Math.max(startIndex, endIndex);
  const indexes: number[] = [];
  for (let index = from; index <= to; index += 1) {
    indexes.push(index);
  }
  return {
    kind: "range",
    indexes,
  };
}

function parseCommand(input: string): { name: string; arg: string } | null {
  const match = input.trim().match(/^\/\s*([a-zA-Z]+)\s*(.*)$/);
  if (!match) {
    return null;
  }
  return {
    name: match[1].toLowerCase(),
    arg: match[2].trim(),
  };
}

async function executeCommand(input: string): Promise<boolean> {
  const command = parseCommand(input);
  if (!command) {
    message.error(t("input.command.errors.unknown"));
    return false;
  }

  const normalized =
    command.name === "goto" || command.name === "go"
      ? "goto"
      : command.name === "del" || command.name === "delete"
        ? "del"
        : command.name;
  if (!["del", "goto", "hide", "show"].includes(normalized)) {
    message.error(
      formatText("input.command.errors.unknown_with_name", {
        command: command.name,
      }),
    );
    return false;
  }
  if (!command.arg) {
    message.warning(t("input.command.errors.target_required"));
    return false;
  }

  const total = currentMessages.value.length;
  if (total < 1) {
    message.warning(t("input.command.errors.no_messages"));
    return false;
  }

  const target = parseFloorTarget(command.arg, total);
  if (!target) {
    message.error(t("input.command.errors.target_invalid"));
    return false;
  }

  const targetMessages = target.indexes
    .map((index) => currentMessages.value[index])
    .filter((item): item is NonNullable<typeof item> => Boolean(item));
  if (!targetMessages.length) {
    message.error(t("input.command.errors.target_invalid"));
    return false;
  }
  const targetIds = targetMessages.map((item) => item.id);

  if (normalized === "goto") {
    if (target.kind !== "single") {
      message.warning(t("input.command.errors.goto_single"));
      return false;
    }
    if (typeof window !== "undefined") {
      window.dispatchEvent(
        new CustomEvent(GOTO_MESSAGE_EVENT, {
          detail: { index: target.indexes[0] },
        }),
      );
    }
    message.success(
      formatText("input.command.done.goto", {
        floor: target.indexes[0] + 1,
      }),
    );
    return true;
  }

  if (normalized === "del") {
    const done = await chatStore.deleteMessages(targetIds);
    if (!done) {
      return false;
    }
    message.success(
      formatText("input.command.done.delete", {
        count: targetIds.length,
      }),
    );
    return true;
  }

  if (normalized === "hide") {
    const done = await chatStore.setMessagesVisibility(targetIds, false);
    if (!done) {
      return false;
    }
    message.success(
      formatText("input.command.done.hide", {
        count: targetIds.length,
      }),
    );
    return true;
  }

  const done = await chatStore.setMessagesVisibility(targetIds, true);
  if (!done) {
    return false;
  }
  message.success(
    formatText("input.command.done.show", {
      count: targetIds.length,
    }),
  );
  return true;
}

async function handleSend() {
  if (isSending.value) {
    chatStore.cancelSending();
    return;
  }
  if (!currentSession.value) {
    message.error(t("errors.select_session_before_send"));
    return;
  }
  if (currentSession.value.is_closed) {
    message.error(t("errors.current_session_closed"));
    return;
  }
  const content = inputText.value.trim();
  if (content.startsWith("/")) {
    const commandDone = await executeCommand(content);
    if (commandDone) {
      inputText.value = "";
      chatStore.clearPendingAttachments();
      nextTick(adjustTextareaHeight);
    }
    return;
  }
  const attachments = pendingAttachments.value.map((item) => ({ ...item }));
  void chatStore.sendMessage(content, attachments);

  inputText.value = "";
  chatStore.clearPendingAttachments();
  nextTick(adjustTextareaHeight);
}

function handleKeyDown(event: KeyboardEvent) {
  if ((event.ctrlKey || event.metaKey) && event.key === "Enter") {
    event.preventDefault();
    void handleSend();
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

.session-close-button {
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-secondary);
  color: var(--rst-text-secondary);
  border-radius: 8px;
  padding: 4px 10px;
  font-size: 11px;
  line-height: 1.2;
  cursor: pointer;
  transition: all 0.2s ease;
}

.session-close-button:hover:not(:disabled) {
  border-color: var(--rst-danger);
  color: var(--rst-danger);
}

.session-close-button:disabled {
  opacity: 0.5;
  cursor: not-allowed;
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
  position: relative;
}

.chat-shell__status-panel {
  position: absolute;
  top: 12px;
  right: 12px;
  bottom: 12px;
  z-index: 5;
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
  font-family: var(--rst-font-family);
  font-size: calc(14px * var(--rst-font-size-scale));
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
  transition:
    opacity 0.2s ease,
    transform 0.2s ease;
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

  .chat-shell__status-panel {
    top: 8px;
    right: 8px;
    bottom: 8px;
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
