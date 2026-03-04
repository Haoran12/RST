import { defineStore } from "pinia";
import { ref } from "vue";

import { fetchLogs, fetchLogDetail } from "@/api/logs";
import { parseApiError } from "@/stores/api-error";
import type { LogEntry } from "@/types/log";
import { message } from "@/utils/message";

export const useLogStore = defineStore("log", () => {
  const logs = ref<LogEntry[]>([]);
  const loading = ref(false);
  const error = ref<string | null>(null);

  async function loadLogs(options: { silent?: boolean } = {}): Promise<void> {
    const { silent = false } = options;
    try {
      if (!silent) {
        loading.value = true;
      }
      error.value = null;
      logs.value = await fetchLogs();
    } catch (err) {
      const parsed = parseApiError(err);
      error.value = parsed;
      if (!silent) {
        message.error(parsed);
      }
    } finally {
      loading.value = false;
    }
  }

  async function loadLogDetail(id: string): Promise<LogEntry | null> {
    try {
      return await fetchLogDetail(id);
    } catch (err) {
      const parsed = parseApiError(err);
      message.error(parsed);
      return null;
    }
  }

  return {
    logs,
    loading,
    error,
    loadLogs,
    loadLogDetail,
  };
});
