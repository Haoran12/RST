import apiClient, { API_TIMEOUT_MS } from "@/api/client";

import type {
  CharacterCreate,
  CharacterData,
  CharacterForm,
  CharacterListResponse,
  CharacterMemory,
  CharacterReorder,
  CharacterUpdate,
  ConversionReport,
  ConsolidateResult,
  FormCreate,
  FormUpdate,
  LoreBatchUpdate,
  LoreEntry,
  LoreEntryCreate,
  LoreEntryListResponse,
  LoreEntryReorder,
  LoreEntryUpdate,
  MemoryCreate,
  MemoryListResponse,
  MemoryUpdate,
  ScheduleResult,
  ScheduleStatus,
  SchedulerPromptTemplate,
  SchedulerTemplateUpdate,
  SyncResult,
  SyncStatus,
} from "@/types/lore";

const BASE = (sessionName: string) => `/sessions/${sessionName}/lores`;

export async function importLore(
  sessionName: string,
  file: File,
  splitFactionCharacters: boolean = false,
  llmFallback: boolean = true,
): Promise<ConversionReport> {
  const formData = new FormData();
  formData.append("file", file);
  const { data } = await apiClient.post<ConversionReport>(`${BASE(sessionName)}/import`, formData, {
    headers: { "Content-Type": "multipart/form-data" },
    timeout: API_TIMEOUT_MS,
    params: {
      split_faction_characters: splitFactionCharacters,
      llm_fallback: llmFallback,
    },
  });
  return data;
}

export async function listEntries(
  sessionName: string,
  category?: string,
): Promise<LoreEntryListResponse> {
  const { data } = await apiClient.get<LoreEntryListResponse>(`${BASE(sessionName)}/entries`, {
    params: { category },
  });
  return data;
}

export async function createEntry(
  sessionName: string,
  payload: LoreEntryCreate,
): Promise<LoreEntry> {
  const { data } = await apiClient.post<LoreEntry>(`${BASE(sessionName)}/entries`, payload);
  return data;
}

export async function getEntry(
  sessionName: string,
  entryId: string,
): Promise<LoreEntry | CharacterData> {
  const { data } = await apiClient.get<LoreEntry | CharacterData>(
    `${BASE(sessionName)}/entries/${entryId}`,
  );
  return data;
}

export async function updateEntry(
  sessionName: string,
  entryId: string,
  payload: LoreEntryUpdate,
): Promise<LoreEntry> {
  const { data } = await apiClient.put<LoreEntry>(
    `${BASE(sessionName)}/entries/${entryId}`,
    payload,
  );
  return data;
}

export async function deleteEntry(sessionName: string, entryId: string): Promise<void> {
  await apiClient.delete(`${BASE(sessionName)}/entries/${entryId}`);
}

export async function batchUpdateEntries(
  sessionName: string,
  payload: LoreBatchUpdate,
): Promise<LoreEntryListResponse> {
  const { data } = await apiClient.put<LoreEntryListResponse>(
    `${BASE(sessionName)}/entries/batch`,
    payload,
  );
  return data;
}

export async function reorderEntries(
  sessionName: string,
  payload: LoreEntryReorder,
): Promise<LoreEntryListResponse> {
  const { data } = await apiClient.put<LoreEntryListResponse>(
    `${BASE(sessionName)}/entries/reorder`,
    payload,
  );
  return data;
}

export async function listCharacters(sessionName: string): Promise<CharacterListResponse> {
  const { data } = await apiClient.get<CharacterListResponse>(`${BASE(sessionName)}/characters`);
  return data;
}

export async function reorderCharacters(
  sessionName: string,
  payload: CharacterReorder,
): Promise<CharacterListResponse> {
  const { data } = await apiClient.put<CharacterListResponse>(
    `${BASE(sessionName)}/characters/reorder`,
    payload,
  );
  return data;
}

export async function createCharacter(
  sessionName: string,
  payload: CharacterCreate,
): Promise<CharacterData> {
  const { data } = await apiClient.post<CharacterData>(`${BASE(sessionName)}/characters`, payload);
  return data;
}

export async function getCharacter(
  sessionName: string,
  characterId: string,
): Promise<CharacterData> {
  const { data } = await apiClient.get<CharacterData>(
    `${BASE(sessionName)}/characters/${characterId}`,
  );
  return data;
}

export async function updateCharacter(
  sessionName: string,
  characterId: string,
  payload: CharacterUpdate,
): Promise<CharacterData> {
  const { data } = await apiClient.put<CharacterData>(
    `${BASE(sessionName)}/characters/${characterId}`,
    payload,
  );
  return data;
}

export async function deleteCharacter(sessionName: string, characterId: string): Promise<void> {
  await apiClient.delete(`${BASE(sessionName)}/characters/${characterId}`);
}

export async function addForm(
  sessionName: string,
  characterId: string,
  payload: FormCreate,
): Promise<CharacterForm> {
  const { data } = await apiClient.post<CharacterForm>(
    `${BASE(sessionName)}/characters/${characterId}/forms`,
    payload,
  );
  return data;
}

export async function updateForm(
  sessionName: string,
  characterId: string,
  formId: string,
  payload: FormUpdate,
): Promise<CharacterForm> {
  const { data } = await apiClient.put<CharacterForm>(
    `${BASE(sessionName)}/characters/${characterId}/forms/${formId}`,
    payload,
  );
  return data;
}

export async function deleteForm(
  sessionName: string,
  characterId: string,
  formId: string,
): Promise<void> {
  await apiClient.delete(`${BASE(sessionName)}/characters/${characterId}/forms/${formId}`);
}

export async function setActiveForm(
  sessionName: string,
  characterId: string,
  formId: string,
): Promise<CharacterData> {
  const { data } = await apiClient.put<CharacterData>(
    `${BASE(sessionName)}/characters/${characterId}/active-form`,
    { form_id: formId },
  );
  return data;
}

export async function listMemories(
  sessionName: string,
  characterId: string,
): Promise<MemoryListResponse> {
  const { data } = await apiClient.get<MemoryListResponse>(
    `${BASE(sessionName)}/characters/${characterId}/memories`,
  );
  return data;
}

export async function addMemory(
  sessionName: string,
  characterId: string,
  payload: MemoryCreate,
): Promise<CharacterMemory> {
  const { data } = await apiClient.post<CharacterMemory>(
    `${BASE(sessionName)}/characters/${characterId}/memories`,
    payload,
  );
  return data;
}

export async function updateMemory(
  sessionName: string,
  characterId: string,
  memoryId: string,
  payload: MemoryUpdate,
): Promise<CharacterMemory> {
  const { data } = await apiClient.put<CharacterMemory>(
    `${BASE(sessionName)}/characters/${characterId}/memories/${memoryId}`,
    payload,
  );
  return data;
}

export async function deleteMemory(
  sessionName: string,
  characterId: string,
  memoryId: string,
): Promise<void> {
  await apiClient.delete(`${BASE(sessionName)}/characters/${characterId}/memories/${memoryId}`);
}

export async function consolidateMemories(
  sessionName: string,
  characterId: string,
): Promise<ConsolidateResult> {
  const { data } = await apiClient.post<ConsolidateResult>(
    `${BASE(sessionName)}/characters/${characterId}/memories/consolidate`,
  );
  return data;
}

export async function triggerSchedule(sessionName: string): Promise<ScheduleResult> {
  const { data } = await apiClient.post<ScheduleResult>(`${BASE(sessionName)}/schedule`);
  return data;
}

export async function getScheduleStatus(sessionName: string): Promise<ScheduleStatus> {
  const { data } = await apiClient.get<ScheduleStatus>(`${BASE(sessionName)}/schedule/status`);
  return data;
}

export async function triggerSync(sessionName: string): Promise<SyncResult> {
  const { data } = await apiClient.post<SyncResult>(`${BASE(sessionName)}/sync`);
  return data;
}

export async function getSyncStatus(sessionName: string): Promise<SyncStatus> {
  const { data } = await apiClient.get<SyncStatus>(`${BASE(sessionName)}/sync/status`);
  return data;
}

export async function getSchedulerTemplate(
  sessionName: string,
): Promise<SchedulerPromptTemplate> {
  const { data } = await apiClient.get<SchedulerPromptTemplate>(
    `${BASE(sessionName)}/scheduler-template`,
  );
  return data;
}

export async function updateSchedulerTemplate(
  sessionName: string,
  payload: SchedulerTemplateUpdate,
): Promise<SchedulerPromptTemplate> {
  const { data } = await apiClient.put<SchedulerPromptTemplate>(
    `${BASE(sessionName)}/scheduler-template`,
    payload,
  );
  return data;
}
