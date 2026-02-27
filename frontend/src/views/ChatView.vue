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
      </div>
    </header>

    <div class="chat-shell__body" @click="handleChatBodyClick">
      <div class="chat-shell__placeholder">
        <div class="placeholder-title">Chat Area</div>
        <div class="placeholder-subtitle">等待后续会话与消息功能接入</div>
      </div>
    </div>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { storeToRefs } from "pinia";
import { NSelect } from "naive-ui";

import { fetchHealth } from "@/api/health";
import { useAppearanceStore } from "@/stores/appearance";
import { useSessionStore } from "@/stores/session";

type HealthState = "checking" | "ok" | "error";

const sessionStore = useSessionStore();
const appearanceStore = useAppearanceStore();
const { sessions, currentSession, loading: sessionLoading } = storeToRefs(sessionStore);
const { theme } = storeToRefs(appearanceStore);

const sessionOptions = computed(() =>
  sessions.value.map((session) => ({ label: session.name, value: session.name })),
);
const selectedSession = computed(() => currentSession.value?.name ?? null);
const themeOptions = appearanceStore.themeOptions;

const status = ref<HealthState>("checking");

const statusText = computed(() => status.value);

onMounted(async () => {
  sessionStore.loadSessions();
  try {
    // Probe backend health when shell mounts.
    const data = await fetchHealth();
    status.value = data.status === "ok" ? "ok" : "error";
  } catch (_error) {
    status.value = "error";
  }
});

function handleSessionSelect(value: string) {
  sessionStore.loadSession(value);
}

function handleChatBodyClick() {
  if (typeof window === "undefined") {
    return;
  }
  window.dispatchEvent(new CustomEvent("rst-chat-area-click"));
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
  min-height: 50px;
  background: var(--rst-bg-topbar);
  border-bottom: 1px solid var(--rst-border-color);
  display: flex;
  align-items: center;
  justify-content: space-between;
  gap: 16px;
  padding: 8px 20px;
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

.chat-shell__body {
  flex: 1;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 24px;
}

.chat-shell__placeholder {
  width: min(720px, 100%);
  border: 1px solid var(--rst-border-color);
  border-radius: 12px;
  padding: 24px;
  background: var(--rst-bg-panel);
  text-align: center;
}

.placeholder-title {
  font-size: 18px;
  font-weight: 600;
  margin-bottom: 8px;
}

.placeholder-subtitle {
  font-size: 13px;
  color: var(--rst-text-secondary);
}

@media (max-width: 640px) {
  .chat-shell__topbar {
    padding: 8px 12px;
    gap: 12px;
  }

  .quick-select :deep(.n-select) {
    min-width: 140px;
  }

  .chat-shell__placeholder {
    padding: 18px;
  }
}
</style>
