import { defineStore } from "pinia";
import { computed, ref } from "vue";

import {
  createCharacter,
  createEntry,
  deleteCharacter,
  deleteEntry,
  getSchedulerTemplate,
  getScheduleStatus,
  getSyncStatus,
  listCharacters,
  listEntries,
  triggerSchedule,
  triggerSync,
  updateCharacter,
  updateEntry,
  updateSchedulerTemplate,
} from "@/api/lores";
import { parseApiError } from "@/stores/api-error";
import { message } from "@/utils/message";

import type {
  CharacterCreate,
  CharacterData,
  CharacterUpdate,
  LoreCategory,
  LoreEntry,
  LoreEntryCreate,
  LoreEntryUpdate,
  ScheduleStatus,
  SchedulerPromptTemplate,
  SchedulerTemplateUpdate,
  SyncStatus,
} from "@/types/lore";

export const useLoreStore = defineStore("lore", () => {
  const loading = ref(false);
  const entries = ref<LoreEntry[]>([]);
  const characters = ref<CharacterData[]>([]);
  const scheduleStatus = ref<ScheduleStatus | null>(null);
  const syncStatus = ref<SyncStatus | null>(null);
  const schedulerTemplate = ref<SchedulerPromptTemplate | null>(null);

  const sortedEntries = computed(() =>
    [...entries.value].sort((a, b) => a.name.localeCompare(b.name)),
  );

  async function loadEntries(sessionName: string, category?: LoreCategory): Promise<void> {
    loading.value = true;
    try {
      const response = await listEntries(sessionName, category);
      entries.value = response.entries;
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function createEntryAction(
    sessionName: string,
    payload: LoreEntryCreate,
  ): Promise<LoreEntry | null> {
    loading.value = true;
    try {
      const entry = await createEntry(sessionName, payload);
      entries.value = [...entries.value, entry];
      return entry;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function updateEntryAction(
    sessionName: string,
    entryId: string,
    payload: LoreEntryUpdate,
  ): Promise<LoreEntry | null> {
    loading.value = true;
    try {
      const updated = await updateEntry(sessionName, entryId, payload);
      entries.value = entries.value.map((entry) =>
        entry.id === entryId ? updated : entry,
      );
      return updated;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function deleteEntryAction(sessionName: string, entryId: string): Promise<void> {
    loading.value = true;
    try {
      await deleteEntry(sessionName, entryId);
      entries.value = entries.value.filter((entry) => entry.id !== entryId);
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function loadCharacters(sessionName: string): Promise<void> {
    loading.value = true;
    try {
      const response = await listCharacters(sessionName);
      characters.value = response.characters;
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function createCharacterAction(
    sessionName: string,
    payload: CharacterCreate,
  ): Promise<CharacterData | null> {
    loading.value = true;
    try {
      const character = await createCharacter(sessionName, payload);
      characters.value = [...characters.value, character];
      return character;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function updateCharacterAction(
    sessionName: string,
    characterId: string,
    payload: CharacterUpdate,
  ): Promise<CharacterData | null> {
    loading.value = true;
    try {
      const updated = await updateCharacter(sessionName, characterId, payload);
      characters.value = characters.value.map((character) =>
        character.character_id === characterId ? updated : character,
      );
      return updated;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function deleteCharacterAction(
    sessionName: string,
    characterId: string,
  ): Promise<void> {
    loading.value = true;
    try {
      await deleteCharacter(sessionName, characterId);
      characters.value = characters.value.filter(
        (character) => character.character_id !== characterId,
      );
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function refreshSchedulerState(sessionName: string): Promise<void> {
    loading.value = true;
    try {
      const [schedule, sync, template] = await Promise.all([
        getScheduleStatus(sessionName),
        getSyncStatus(sessionName),
        getSchedulerTemplate(sessionName),
      ]);
      scheduleStatus.value = schedule;
      syncStatus.value = sync;
      schedulerTemplate.value = template;
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function triggerScheduleAction(sessionName: string): Promise<void> {
    loading.value = true;
    try {
      await triggerSchedule(sessionName);
      scheduleStatus.value = await getScheduleStatus(sessionName);
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function triggerSyncAction(sessionName: string): Promise<void> {
    loading.value = true;
    try {
      await triggerSync(sessionName);
      syncStatus.value = await getSyncStatus(sessionName);
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  async function updateSchedulerTemplateAction(
    sessionName: string,
    payload: SchedulerTemplateUpdate,
  ): Promise<void> {
    loading.value = true;
    try {
      schedulerTemplate.value = await updateSchedulerTemplate(sessionName, payload);
    } catch (error) {
      message.error(parseApiError(error));
    } finally {
      loading.value = false;
    }
  }

  return {
    loading,
    entries,
    sortedEntries,
    characters,
    scheduleStatus,
    syncStatus,
    schedulerTemplate,
    loadEntries,
    createEntry: createEntryAction,
    updateEntry: updateEntryAction,
    deleteEntry: deleteEntryAction,
    loadCharacters,
    createCharacter: createCharacterAction,
    updateCharacter: updateCharacterAction,
    deleteCharacter: deleteCharacterAction,
    refreshSchedulerState,
    triggerSchedule: triggerScheduleAction,
    triggerSync: triggerSyncAction,
    updateSchedulerTemplate: updateSchedulerTemplateAction,
  };
});
