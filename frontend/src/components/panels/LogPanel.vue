<template>
  <section class="panel" @click.stop>
    <header class="panel-header">
      <div class="panel-title">Log</div>
      <div class="header-actions">
        <select v-model="sourceFilter" class="source-filter" :disabled="logStore.loading">
          <option value="all">All LLM Requests</option>
          <option value="main">Main Session LLM</option>
          <option value="scheduler">Scheduler LLM</option>
        </select>
        <button
          type="button"
          class="refresh-button"
          :disabled="logStore.loading"
          @click="logStore.loadLogs"
        >
          Refresh
        </button>
      </div>
    </header>

    <div class="panel-body">
      <div v-if="logStore.loading" class="placeholder">Loading logs...</div>
      <div v-else-if="logStore.error" class="placeholder error">
        {{ logStore.error }}
      </div>
      <div v-else-if="filteredLogs.length === 0" class="placeholder">
        No logs recorded yet.
      </div>
      <div v-else class="log-list">
        <button
          v-for="log in filteredLogs"
          :key="log.id"
          type="button"
          class="log-card"
          @click="openLogDetail(log)"
        >
          <div class="log-header">
            <span class="log-name">{{ log.chat_name }}</span>
            <span class="log-time">{{ formatTime(log.request_time) }}</span>
          </div>
          <div class="log-meta">Provider: {{ log.provider || "-" }}</div>
          <div class="log-meta">Model: {{ log.model || "-" }}</div>
          <div class="log-meta">Source: {{ sourceLabel(log.request_source) }}</div>
          <div class="log-meta">
            Status:
            <span :class="['status-chip', statusClass(log.status)]">{{ log.status || "-" }}</span>
            | Duration: {{ formatDuration(log.duration_ms) }}
          </div>
          <div class="log-meta">
            Tokens: {{ formatTokens(log) }} | Stop: {{ log.stop_reason || "-" }}
          </div>
          <div class="log-footer">
            <span>Req: {{ formatTime(log.request_time) }}</span>
            <span>Res: {{ formatTime(log.response_time || "") }}</span>
          </div>
        </button>
      </div>
    </div>

    <div class="panel-footer">Showing recent requests</div>

    <n-modal v-model:show="detailVisible" preset="card" title="Log Detail" size="large">
      <div v-if="selectedLog" class="detail-body">
        <div class="detail-section">
          <div class="detail-title">Overview</div>
          <div class="detail-grid">
            <div>
              <div class="detail-label">Session</div>
              <div class="detail-value">{{ selectedLog.chat_name }}</div>
            </div>
            <div>
              <div class="detail-label">Model</div>
              <div class="detail-value">{{ selectedLog.model || "-" }}</div>
            </div>
            <div>
              <div class="detail-label">Provider</div>
              <div class="detail-value">{{ selectedLog.provider || "-" }}</div>
            </div>
            <div>
              <div class="detail-label">Source</div>
              <div class="detail-value">{{ sourceLabel(selectedLog.request_source) }}</div>
            </div>
            <div>
              <div class="detail-label">Status</div>
              <div class="detail-value">
                <span :class="['status-chip', statusClass(selectedLog.status)]">
                  {{ selectedLog.status || "-" }}
                </span>
              </div>
            </div>
            <div>
              <div class="detail-label">Duration</div>
              <div class="detail-value">{{ formatDuration(selectedLog.duration_ms) }}</div>
            </div>
            <div>
              <div class="detail-label">Prompt Tokens</div>
              <div class="detail-value">{{ formatMaybeNumber(selectedLog.prompt_tokens) }}</div>
            </div>
            <div>
              <div class="detail-label">Completion Tokens</div>
              <div class="detail-value">{{ formatMaybeNumber(selectedLog.completion_tokens) }}</div>
            </div>
            <div>
              <div class="detail-label">Total Tokens</div>
              <div class="detail-value">{{ formatMaybeNumber(selectedLog.total_tokens) }}</div>
            </div>
            <div>
              <div class="detail-label">Stop Reason</div>
              <div class="detail-value">{{ selectedLog.stop_reason || "-" }}</div>
            </div>
            <div>
              <div class="detail-label">Request</div>
              <div class="detail-value">{{ formatTime(selectedLog.request_time) }}</div>
            </div>
            <div>
              <div class="detail-label">Response</div>
              <div class="detail-value">{{ formatTime(selectedLog.response_time || "") }}</div>
            </div>
          </div>
        </div>

        <div class="detail-section">
          <div class="detail-title">Raw Request</div>
          <pre class="detail-code">{{ formatJson(selectedLog.raw_request) }}</pre>
        </div>

        <div class="detail-section">
          <div class="detail-title">Raw Response</div>
          <pre class="detail-code">{{ formatJson(selectedLog.raw_response) }}</pre>
        </div>
      </div>
      <template #footer>
        <div class="detail-footer">
          <n-button secondary @click="detailVisible = false">Close</n-button>
        </div>
      </template>
    </n-modal>
  </section>
</template>

<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { NButton, NModal } from "naive-ui";

import { useLogStore } from "@/stores/log";
import type { LogEntry } from "@/types/log";

const logStore = useLogStore();
const selectedLog = ref<LogEntry | null>(null);
const detailVisible = ref(false);
const sourceFilter = ref<"all" | "main" | "scheduler">("all");

const filteredLogs = computed(() => {
  if (sourceFilter.value === "all") {
    return logStore.logs;
  }
  return logStore.logs.filter((log) => normalizeSource(log.request_source) === sourceFilter.value);
});

onMounted(() => {
  logStore.loadLogs();
});

async function openLogDetail(log: LogEntry) {
  detailVisible.value = true;
  selectedLog.value = log;
  const detail = await logStore.loadLogDetail(log.id);
  if (detail) {
    selectedLog.value = detail;
  }
}

function formatTime(isoString: string) {
  if (!isoString) {
    return "-";
  }
  const hasTimezone = /[zZ]$|[+-]\d{2}:\d{2}$/.test(isoString);
  const normalized = hasTimezone ? isoString : `${isoString}Z`;
  const parsed = new Date(normalized);
  if (Number.isNaN(parsed.getTime())) {
    return isoString;
  }
  return parsed.toLocaleString();
}

function formatDuration(duration: number | null | undefined) {
  if (duration === null || duration === undefined) {
    return "-";
  }
  const seconds = duration / 1000;
  return `${seconds.toFixed(1)} s`;
}

function formatMaybeNumber(value: number | null | undefined) {
  return value === null || value === undefined ? "-" : String(value);
}

function formatTokens(log: LogEntry) {
  if (log.total_tokens !== null && log.total_tokens !== undefined) {
    return String(log.total_tokens);
  }
  if (log.prompt_tokens !== null && log.prompt_tokens !== undefined) {
    if (log.completion_tokens !== null && log.completion_tokens !== undefined) {
      return `${log.prompt_tokens}/${log.completion_tokens}`;
    }
    return String(log.prompt_tokens);
  }
  return "-";
}

function statusClass(status: string | null | undefined) {
  if (status === "success") {
    return "is-success";
  }
  if (status === "error") {
    return "is-error";
  }
  return "";
}

function normalizeSource(source: string | undefined) {
  if (source === "scheduler") {
    return "scheduler";
  }
  return "main";
}

function sourceLabel(source: string | undefined) {
  if (normalizeSource(source) === "scheduler") {
    return "Scheduler LLM";
  }
  return "Main Session LLM";
}

function formatJson(payload: unknown) {
  try {
    return JSON.stringify(payload, null, 2);
  } catch {
    return String(payload ?? "");
  }
}
</script>

<style scoped lang="scss">
.panel {
  display: flex;
  flex-direction: column;
  height: 100%;
  padding: 16px;
  color: var(--rst-text-primary);
}

.panel-header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  padding-bottom: 12px;
  border-bottom: 1px solid var(--rst-border-color);
}

.panel-title {
  font-size: 14px;
  letter-spacing: 0.08em;
  text-transform: uppercase;
}

.header-actions {
  display: flex;
  align-items: center;
  gap: 8px;
}

.source-filter {
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-topbar);
  color: var(--rst-text-secondary);
  font-size: 11px;
  padding: 4px 8px;
  border-radius: 999px;
}

.refresh-button {
  border: 1px solid var(--rst-border-color);
  background: var(--rst-bg-topbar);
  color: var(--rst-text-secondary);
  font-size: 11px;
  padding: 4px 10px;
  border-radius: 999px;
  cursor: pointer;
}

.refresh-button:disabled {
  opacity: 0.6;
  cursor: not-allowed;
}

.panel-body {
  margin-top: 12px;
  flex: 1;
  overflow: hidden;
}

.placeholder {
  height: 100%;
  display: flex;
  align-items: center;
  justify-content: center;
  text-align: center;
  color: var(--rst-text-secondary);
}

.placeholder.error {
  color: var(--rst-danger);
}

.log-list {
  display: flex;
  flex-direction: column;
  gap: 8px;
  max-height: 100%;
  overflow-y: auto;
}

.log-card {
  text-align: left;
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  background: var(--rst-bg-topbar);
  padding: 10px 12px;
  cursor: pointer;
  transition: border-color 0.2s ease, background 0.2s ease;
}

.log-card:hover {
  border-color: var(--rst-accent);
  background: rgba(255, 255, 255, 0.04);
}

.log-header {
  display: flex;
  justify-content: space-between;
  align-items: baseline;
  gap: 8px;
}

.log-name {
  font-size: 13px;
  font-weight: 600;
  color: var(--rst-text-primary);
}

.log-time {
  font-size: 11px;
  color: var(--rst-text-secondary);
}

.log-meta {
  font-size: 12px;
  color: var(--rst-text-secondary);
  margin-top: 4px;
}

.status-chip {
  display: inline-flex;
  align-items: center;
  border-radius: 999px;
  padding: 0 8px;
  border: 1px solid var(--rst-border-color);
  font-size: 11px;
  line-height: 18px;
}

.status-chip.is-success {
  color: #22c55e;
  border-color: rgba(34, 197, 94, 0.45);
}

.status-chip.is-error {
  color: #ef4444;
  border-color: rgba(239, 68, 68, 0.45);
}

.log-footer {
  margin-top: 6px;
  display: flex;
  justify-content: space-between;
  font-size: 10px;
  color: var(--rst-text-secondary);
}

.panel-footer {
  padding-top: 10px;
  font-size: 10px;
  text-align: center;
  color: var(--rst-text-secondary);
  border-top: 1px solid var(--rst-border-color);
}

.detail-body {
  display: flex;
  flex-direction: column;
  gap: 16px;
  max-height: 70vh;
  overflow-y: auto;
}

.detail-section {
  display: flex;
  flex-direction: column;
  gap: 8px;
}

.detail-title {
  font-size: 12px;
  text-transform: uppercase;
  letter-spacing: 0.12em;
  color: var(--rst-text-secondary);
}

.detail-grid {
  display: grid;
  grid-template-columns: repeat(2, minmax(0, 1fr));
  gap: 12px;
}

.detail-label {
  font-size: 11px;
  color: var(--rst-text-secondary);
}

.detail-value {
  font-size: 13px;
  color: var(--rst-text-primary);
}

.detail-code {
  background: var(--rst-bg-secondary);
  border: 1px solid var(--rst-border-color);
  border-radius: 10px;
  padding: 10px 12px;
  font-size: 11px;
  color: var(--rst-text-primary);
  white-space: pre-wrap;
  word-break: break-word;
}

.detail-footer {
  display: flex;
  justify-content: flex-end;
}

@media (max-width: 720px) {
  .detail-grid {
    grid-template-columns: 1fr;
  }
}
</style>
