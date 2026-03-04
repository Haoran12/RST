export type LoreCategory =
  | "world_base"
  | "society"
  | "place"
  | "faction"
  | "character"
  | "skills"
  | "others"
  | "plot"
  | "memory";

export interface Relationship {
  target: string;
  relation: string;
}

export interface ConversionWarning {
  source_id: string;
  name: string;
  type: string;
  message: string;
}

export interface ConversionReport {
  source_file: string;
  session_name: string;
  timestamp: string;
  statistics: Record<string, number>;
  id_mapping: Record<string, string>;
  category_summary: Record<string, number>;
  actions: ConversionAction[];
  warnings: ConversionWarning[];
  errors: string[];
}

export interface ConversionAction {
  source_id: string;
  name: string;
  source_category: string;
  action: string;
  target_category: string | null;
  created_ids: string[];
  notes: string[];
  warnings: string[];
  errors: string[];
}

export interface CharacterMemory {
  memory_id: string;
  event: string;
  importance: number;
  tags: string[];
  known_by: string[];
  plot_event_id: string | null;
  is_consolidated: boolean;
  created_at: string;
}

export interface CharacterForm {
  form_id: string;
  form_name: string;
  is_default: boolean;
  physique: string;
  features: string;
  vitality_max: number;
  strength: number;
  mana_potency: number;
  toughness: number;
  weak: string[];
  resist: string[];
  element: string[];
  skills: string[];
  penetration: string[];
  clothing: string;
  body: string;
  mind: string;
  vitality_cur: number;
  activity: string;
}

export interface CharacterData {
  character_id: string;
  name: string;
  race: string;
  gender: string;
  birth: string;
  homeland: string;
  aliases: string[];
  role: string;
  faction: string;
  objective: string;
  personality: string;
  relationship: Relationship[];
  memories: CharacterMemory[];
  forms: CharacterForm[];
  active_form_id: string;
  tags: string[];
  sort_order: number;
  disabled: boolean;
  constant: boolean;
  created_at: string;
  updated_at: string;
}

export interface LoreEntry {
  id: string;
  name: string;
  category: LoreCategory;
  content: string;
  disabled: boolean;
  constant: boolean;
  tags: string[];
  created_at: string;
  updated_at: string;
}

export interface LoreEntryCreate {
  name: string;
  category: Exclude<LoreCategory, "character" | "memory">;
  content?: string;
  disabled?: boolean;
  constant?: boolean;
  tags?: string[];
}

export interface LoreEntryUpdate {
  name?: string;
  category?: Exclude<LoreCategory, "character" | "memory">;
  content?: string;
  disabled?: boolean;
  constant?: boolean;
  tags?: string[];
}

export interface LoreEntryListResponse {
  entries: LoreEntry[];
  total: number;
}

export interface LoreBatchItem {
  entry_id: string;
  disabled?: boolean;
  constant?: boolean;
}

export interface LoreBatchUpdate {
  updates: LoreBatchItem[];
}

export interface LoreEntryReorder {
  category: Exclude<LoreCategory, "character" | "memory">;
  entry_ids: string[];
}

export interface CharacterListResponse {
  characters: CharacterData[];
  total: number;
}

export interface CharacterReorder {
  character_ids: string[];
}

export interface CharacterCreate {
  name: string;
  race: string;
  gender?: string;
  birth?: string;
  homeland?: string;
  aliases?: string[];
  role?: string;
  faction?: string;
  objective?: string;
  personality?: string;
  relationship?: Relationship[];
  tags?: string[];
  disabled?: boolean;
  constant?: boolean;
}

export interface CharacterUpdate {
  name?: string;
  race?: string;
  gender?: string;
  birth?: string;
  homeland?: string;
  aliases?: string[];
  role?: string;
  faction?: string;
  objective?: string;
  personality?: string;
  relationship?: Relationship[];
  tags?: string[];
  disabled?: boolean;
  constant?: boolean;
}

export interface FormCreate {
  form_name: string;
  is_default?: boolean;
  physique?: string;
  features?: string;
  vitality_max?: number;
  strength?: number;
  mana_potency?: number;
  toughness?: number;
  weak?: string[];
  resist?: string[];
  element?: string[];
  skills?: string[];
  penetration?: string[];
}

export interface FormUpdate {
  form_name?: string;
  is_default?: boolean;
  physique?: string;
  features?: string;
  vitality_max?: number;
  strength?: number;
  mana_potency?: number;
  toughness?: number;
  weak?: string[];
  resist?: string[];
  element?: string[];
  skills?: string[];
  penetration?: string[];
  clothing?: string;
  body?: string;
  mind?: string;
  vitality_cur?: number;
  activity?: string;
}

export interface MemoryCreate {
  event: string;
  importance?: number;
  tags?: string[];
  known_by?: string[];
  plot_event_id?: string;
}

export interface MemoryUpdate {
  event?: string;
  importance?: number;
  tags?: string[];
  known_by?: string[];
}

export interface MemoryListResponse {
  memories: CharacterMemory[];
  total: number;
}

export interface SchedulerPromptTemplate {
  id: string;
  name: string;
  confirm_prompt: string;
  extract_prompt: string;
  consolidate_prompt: string;
  version: number;
}

export interface SchedulerTemplateUpdate {
  confirm_prompt?: string;
  extract_prompt?: string;
  consolidate_prompt?: string;
}

export interface SceneState {
  current_time: string;
  current_location: string;
  characters: string[];
  raw_tag: string;
  updated_at: string;
}

export interface SceneStateUpdate {
  current_time?: string;
  current_location?: string;
  characters?: string[];
}

export interface ScheduleResult {
  injection_block: string;
  matched_entry_ids: string[];
  duration_ms: number;
}

export interface ScheduleStatus {
  running: boolean;
  last_run_at: string | null;
  last_matched_count: number | null;
  last_matched_entry_ids: string[];
  cached_candidates: string[];
}

export interface SyncFieldChange {
  field: string;
  before: string;
  after: string;
}

export interface SyncChange {
  entry_id: string;
  name: string;
  category: string;
  action: string;
  summary: string;
  before_content: string | null;
  after_content: string | null;
  content_append: string | null;
  tags_added: string[];
  field_changes: SyncFieldChange[];
  memory_event: string | null;
}

export interface SyncResult {
  updated_entries: string[];
  created_entries: string[];
  new_memories: number;
  new_plot_events: number;
  duration_ms: number;
  changes: SyncChange[];
}

export interface SyncStatus {
  running: boolean;
  last_run_at: string | null;
  rounds_since_last_sync: number;
  sync_interval: number;
  last_result: SyncResult | null;
}

export interface ConsolidateResult {
  character_id: string;
  removed_count: number;
  created_count: number;
  duration_ms: number;
}
