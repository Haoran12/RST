export interface SessionSummary {
  name: string;
  mode: "ST" | "RST";
  is_closed: boolean;
  updated_at: string;
}

export interface SessionDetail {
  name: string;
  mode: "ST" | "RST";
  is_closed: boolean;
  user_description: string;
  scan_depth: number;
  mem_length: number;
  created_at: string;
  updated_at: string;
  main_api_config_id: string;
  scheduler_api_config_id: string | null;
  preset_id: string;
  version: number;
}

export interface SessionCreate {
  name: string;
  mode?: "ST" | "RST";
  is_closed?: boolean;
  main_api_config_id: string;
  scheduler_api_config_id?: string;
  preset_id: string;
  user_description?: string;
  scan_depth?: number;
  mem_length?: number;
}

export interface SessionUpdate {
  mode?: "ST" | "RST";
  is_closed?: boolean;
  main_api_config_id?: string;
  scheduler_api_config_id?: string | null;
  preset_id?: string;
  user_description?: string;
  scan_depth?: number;
  mem_length?: number;
}

export interface SessionRename {
  new_name: string;
}
