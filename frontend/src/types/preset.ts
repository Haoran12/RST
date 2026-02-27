export interface PresetEntry {
  name: string;
  role: "system" | "user" | "assistant";
  content: string;
  disabled: boolean;
  comment: string;
}

export const SYSTEM_ENTRIES: string[] = [
  "Main_Prompt",
  "lores",
  "user_description",
  "chat_history",
  "scene",
  "user_input",
];

export interface PresetSummary {
  id: string;
  name: string;
}

export interface PresetDetail {
  id: string;
  name: string;
  entries: PresetEntry[];
  version: number;
}

export interface PresetCreate {
  name: string;
}

export interface PresetUpdate {
  entries: PresetEntry[];
}

export interface PresetRename {
  new_name: string;
}

