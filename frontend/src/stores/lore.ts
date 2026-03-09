import axios from "axios";
import { defineStore } from "pinia";
import { computed, ref } from "vue";

import {
  addForm,
  createCharacter,
  createEntry,
  deleteCharacter,
  deleteEntry,
  deleteForm,
  getSchedulerTemplate,
  getScheduleStatus,
  getSyncStatus,
  importLore as importLoreApi,
  listCharacters,
  listEntries,
  reorderCharacters,
  reorderEntries,
  setActiveForm,
  triggerSchedule,
  triggerSync,
  updateCharacter,
  updateEntry,
  updateForm,
  updateSchedulerTemplate,
} from "@/api/lores";
import { parseApiError } from "@/stores/api-error";
import { message } from "@/utils/message";

import type {
  CharacterCreate,
  CharacterData,
  CharacterForm,
  CharacterReorder,
  CharacterUpdate,
  ConversionReport,
  FormCreate,
  FormUpdate,
  LoreCategory,
  LoreEntry,
  LoreEntryCreate,
  LoreEntryReorder,
  LoreEntryUpdate,
  ScheduleStatus,
  SchedulerPromptTemplate,
  SchedulerTemplateUpdate,
  SyncStatus,
} from "@/types/lore";

interface ImportLoreResult {
  report: ConversionReport | null;
  timedOut: boolean;
  errorMessage: string | null;
}

export const useLoreStore = defineStore("lore", () => {
  const loading = ref(false);
  const entries = ref<LoreEntry[]>([]);
  const currentEntriesCategory = ref<LoreCategory | null>(null);
  const characters = ref<CharacterData[]>([]);
  const scheduleStatus = ref<ScheduleStatus | null>(null);
  const syncStatus = ref<SyncStatus | null>(null);
  const schedulerTemplate = ref<SchedulerPromptTemplate | null>(null);

  const sortedEntries = computed(() => [...entries.value]);

  async function loadEntries(sessionName: string, category?: LoreCategory): Promise<void> {
    loading.value = true;
    try {
      const response = await listEntries(sessionName, category);
      entries.value = response.entries;
      currentEntriesCategory.value = category ?? null;
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
      if (
        currentEntriesCategory.value === null ||
        currentEntriesCategory.value === entry.category
      ) {
        entries.value = [...entries.value, entry];
      }
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
      if (
        currentEntriesCategory.value === null ||
        currentEntriesCategory.value === updated.category
      ) {
        entries.value = entries.value.map((entry) => (entry.id === entryId ? updated : entry));
      } else {
        entries.value = entries.value.filter((entry) => entry.id !== entryId);
      }
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

  async function reorderEntriesAction(
    sessionName: string,
    payload: LoreEntryReorder,
  ): Promise<LoreEntry[] | null> {
    loading.value = true;
    try {
      const response = await reorderEntries(sessionName, payload);
      if (currentEntriesCategory.value === payload.category) {
        entries.value = response.entries;
      }
      return response.entries;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
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

  async function importLoreAction(
    sessionName: string,
    file: File,
    splitFactionCharacters: boolean,
    llmFallback: boolean = true,
  ): Promise<ImportLoreResult> {
    loading.value = true;
    try {
      const report = await importLoreApi(sessionName, file, splitFactionCharacters, llmFallback);
      return {
        report,
        timedOut: false,
        errorMessage: null,
      };
    } catch (error) {
      return {
        report: null,
        timedOut: isTimeoutError(error),
        errorMessage: parseApiError(error),
      };
    } finally {
      loading.value = false;
    }
  }

  function isTimeoutError(error: unknown): boolean {
    if (!axios.isAxiosError(error)) {
      return false;
    }
    const code = error.code?.toUpperCase();
    if (code === "ECONNABORTED" || code === "ETIMEDOUT") {
      return true;
    }
    return error.message.toLowerCase().includes("timeout");
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

  async function updateCharacterFormAction(
    sessionName: string,
    characterId: string,
    formId: string,
    payload: FormUpdate,
  ): Promise<CharacterForm | null> {
    loading.value = true;
    try {
      const updatedForm = await updateForm(sessionName, characterId, formId, payload);
      const target = characters.value.find((character) => character.character_id === characterId);
      if (!target) {
        return updatedForm;
      }
      const updatedForms = target.forms.map((form) =>
        form.form_id === formId ? updatedForm : form,
      );
      characters.value = characters.value.map((character) =>
        character.character_id === characterId
          ? {
              ...character,
              forms: updatedForms,
            }
          : character,
      );
      return updatedForm;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function addCharacterFormAction(
    sessionName: string,
    characterId: string,
    payload: FormCreate,
  ): Promise<CharacterForm | null> {
    loading.value = true;
    try {
      const createdForm = await addForm(sessionName, characterId, payload);
      characters.value = characters.value.map((character) => {
        if (character.character_id !== characterId) {
          return character;
        }
        const forms = payload.is_default
          ? [...character.forms.map((form) => ({ ...form, is_default: false })), createdForm]
          : [...character.forms, createdForm];
        return {
          ...character,
          forms,
          active_form_id:
            payload.is_default || !character.active_form_id
              ? createdForm.form_id
              : character.active_form_id,
        };
      });
      return createdForm;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
    } finally {
      loading.value = false;
    }
  }

  async function setCharacterActiveFormAction(
    sessionName: string,
    characterId: string,
    formId: string,
  ): Promise<CharacterData | null> {
    loading.value = true;
    try {
      const updated = await setActiveForm(sessionName, characterId, formId);
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

  async function deleteCharacterFormAction(
    sessionName: string,
    characterId: string,
    formId: string,
  ): Promise<boolean> {
    loading.value = true;
    try {
      await deleteForm(sessionName, characterId, formId);
      characters.value = characters.value.map((character) => {
        if (character.character_id !== characterId) {
          return character;
        }
        const forms = character.forms.filter((form) => form.form_id !== formId);
        if (forms.length === 0) {
          return character;
        }
        if (!forms.some((form) => form.is_default)) {
          forms[0] = { ...forms[0], is_default: true };
        }
        const nextActiveFormId =
          character.active_form_id === formId
            ? (forms.find((form) => form.is_default)?.form_id ?? forms[0].form_id)
            : character.active_form_id;
        return {
          ...character,
          forms,
          active_form_id: nextActiveFormId,
        };
      });
      return true;
    } catch (error) {
      message.error(parseApiError(error));
      return false;
    } finally {
      loading.value = false;
    }
  }

  async function deleteCharacterAction(sessionName: string, characterId: string): Promise<void> {
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

  async function reorderCharactersAction(
    sessionName: string,
    payload: CharacterReorder,
  ): Promise<CharacterData[] | null> {
    loading.value = true;
    try {
      const response = await reorderCharacters(sessionName, payload);
      characters.value = response.characters;
      return response.characters;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
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
  ): Promise<SchedulerPromptTemplate | null> {
    loading.value = true;
    try {
      schedulerTemplate.value = await updateSchedulerTemplate(sessionName, payload);
      return schedulerTemplate.value;
    } catch (error) {
      message.error(parseApiError(error));
      return null;
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
    reorderEntries: reorderEntriesAction,
    loadCharacters,
    createCharacter: createCharacterAction,
    updateCharacter: updateCharacterAction,
    addCharacterForm: addCharacterFormAction,
    setCharacterActiveForm: setCharacterActiveFormAction,
    updateCharacterForm: updateCharacterFormAction,
    deleteCharacterForm: deleteCharacterFormAction,
    deleteCharacter: deleteCharacterAction,
    reorderCharacters: reorderCharactersAction,
    importLore: importLoreAction,
    refreshSchedulerState,
    triggerSchedule: triggerScheduleAction,
    triggerSync: triggerSyncAction,
    updateSchedulerTemplate: updateSchedulerTemplateAction,
  };
});
