import { defineStore } from "pinia";
import { ref } from "vue";
import { message } from "@/utils/message";

import type {
  SessionCreate,
  SessionDetail,
  SessionRename,
  SessionSummary,
  SessionUpdate,
} from "@/types/session";
import { parseApiError } from "@/stores/api-error";
import {
  createSession,
  deleteSession,
  fetchSession,
  fetchSessions,
  renameSession,
  updateSession,
} from "@/api/sessions";

export const useSessionStore = defineStore("session", () => {
  const sessions = ref<SessionSummary[]>([]);
  const currentSession = ref<SessionDetail | null>(null);
  const loading = ref(false);

  async function loadSessions(): Promise<void> {
    loading.value = true;
    try {
      sessions.value = await fetchSessions();
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function loadSession(name: string): Promise<void> {
    loading.value = true;
    try {
      currentSession.value = await fetchSession(name);
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function createSessionAction(
    data: SessionCreate,
  ): Promise<SessionDetail | null> {
    loading.value = true;
    try {
      const result = await createSession(data);
      currentSession.value = result;
      await loadSessions();
      return result;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function saveSession(
    name: string,
    data: SessionUpdate,
  ): Promise<SessionDetail | null> {
    loading.value = true;
    try {
      const result = await updateSession(name, data);
      currentSession.value = result;
      await loadSessions();
      return result;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function removeSessionAction(name: string): Promise<void> {
    loading.value = true;
    try {
      await deleteSession(name);
      currentSession.value = null;
      await loadSessions();
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function renameSessionAction(
    name: string,
    data: SessionRename,
  ): Promise<SessionDetail | null> {
    loading.value = true;
    try {
      const result = await renameSession(name, data);
      currentSession.value = result;
      await loadSessions();
      return result;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  return {
    sessions,
    currentSession,
    loading,
    loadSessions,
    loadSession,
    createSession: createSessionAction,
    saveSession,
    removeSession: removeSessionAction,
    renameSession: renameSessionAction,
  };
});

